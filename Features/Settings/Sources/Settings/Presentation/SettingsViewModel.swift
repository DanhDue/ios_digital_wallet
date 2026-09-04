import Combine
import Core
import Foundation
import Framework
import Platform

/// The Settings screen's `MviViewModel` (Source Spec §5.4 / §5.5).
///
/// * `.onAppear` runs the `"load"` effect: `GetSettingsUseCase` +
///   `GetAvailableLanguagesUseCase` → `reduce` → `showContent()`, or `handleError` on failure.
/// * Every mutating action applies an **optimistic** `reduce` (flip the field,
///   set `isSaving`), then runs the `"save"` effect.
/// * Language selection runs the `"changeLanguage"` effect, which cancels any
///   in-flight language switch (PR #34 race condition protection).
public final class SettingsViewModel: MviViewModel<SettingsState, SettingsAction, SettingsEvent> {
    private static let loadEffect = "load"
    private static let saveEffect = "save"
    private static let languageEffect = "changeLanguage"

    private let getSettings: GetSettingsUseCase
    private let saveSettings: SaveSettingsUseCase
    private let getAvailableLanguages: GetAvailableLanguagesUseCase?
    private let changeLanguage: ChangeLanguageUseCase?
    private let checkLanguageCached: CheckLanguageCachedUseCase?
    private let checkSettingsCached: CheckSettingsCachedUseCase?
    private let themeManager: AppThemeManager?
    private let localizationService: (any LocalizationService)?

    public init(
        getSettings: GetSettingsUseCase,
        saveSettings: SaveSettingsUseCase,
        getAvailableLanguages: GetAvailableLanguagesUseCase? = nil,
        changeLanguage: ChangeLanguageUseCase? = nil,
        checkLanguageCached: CheckLanguageCachedUseCase? = nil,
        checkSettingsCached: CheckSettingsCachedUseCase? = nil,
        themeManager: AppThemeManager? = nil,
        localizationService: (any LocalizationService)? = nil
    ) {
        self.getSettings = getSettings
        self.saveSettings = saveSettings
        self.getAvailableLanguages = getAvailableLanguages
        self.changeLanguage = changeLanguage
        self.checkLanguageCached = checkLanguageCached
        self.checkSettingsCached = checkSettingsCached
        self.themeManager = themeManager
        self.localizationService = localizationService
        var initial = SettingsState(settings: .default)
        if let appLoc = localizationService as? AppLocalizationManager {
            initial.translations = appLoc.dynamicOverrides
            initial.settings.language = appLoc.currentLanguageCode
        }
        super.init(initialState: initial)

        if let appLoc = localizationService as? AppLocalizationManager {
            appLoc.$dynamicOverrides
                .receive(on: DispatchQueue.main)
                .sink { [weak self] overrides in
                    self?.reduce { $0.translations = overrides }
                }
                .store(in: &cancellables)

            appLoc.$currentLanguageCode
                .receive(on: DispatchQueue.main)
                .sink { [weak self] code in
                    self?.reduce { $0.settings.language = code }
                }
                .store(in: &cancellables)
        }
    }

    /// Convenience wiring for a caller that already holds a `SettingsRepository`.
    public convenience init(
        repository: SettingsRepository,
        themeManager: AppThemeManager? = nil,
        localizationService: (any LocalizationService)? = nil
    ) {
        let checkCached = CheckLanguageCachedUseCase(repository: repository)
        let getDynamic = GetDynamicLocalizationUseCase(
            repository: repository,
            localizationService: localizationService ?? NoOpLocalizationService()
        )
        let updatePref = UpdateUserPreferencesUseCase(repository: repository)
        let changeLang = ChangeLanguageUseCase(
            checkLanguageCachedUseCase: checkCached,
            getDynamicLocalizationUseCase: getDynamic,
            updateUserPreferencesUseCase: updatePref,
            localizationService: localizationService ?? NoOpLocalizationService()
        )
        self.init(
            getSettings: GetSettingsUseCase(repository: repository),
            saveSettings: SaveSettingsUseCase(repository: repository),
            getAvailableLanguages: GetAvailableLanguagesUseCase(repository: repository),
            changeLanguage: changeLang,
            checkLanguageCached: checkCached,
            checkSettingsCached: CheckSettingsCachedUseCase(repository: repository),
            themeManager: themeManager,
            localizationService: localizationService
        )
    }

    /// Resolves localized string by checking in-memory dynamic translations, localization manager,
    /// then fallback default string.
    public func tr(_ key: String, default defaultString: String) -> String {
        if let val = uiState.translations[key], !val.isEmpty {
            return val
        }
        if let val = localizationService?.translate(key, default: defaultString), !val.isEmpty, val != key {
            return val
        }
        return defaultString
    }

    override public func onAction(_ action: SettingsAction) {
        switch action {
        case .onAppear:
            load()
        case .toggleDarkMode:
            let newMode = !uiState.settings.isDarkMode
            themeManager?.setMode(newMode ? .dark : .light)
            mutate { $0.isDarkMode = newMode }
        case let .selectLanguage(code):
            guard !code.isEmpty else { return }
            selectLanguage(code)
        case let .showLanguagePicker(isPresented):
            reduce { $0.isLanguagePickerPresented = isPresented }
        case let .toggleDeveloperMode(isEnabled):
            reduce { $0.isDeveloperModeEnabled = isEnabled }
        case .toggleNotifications:
            mutate { $0.notificationsEnabled.toggle() }
        }
    }

    // MARK: - Effects

    private func load() {
        startLoading()
        launch(Self.loadEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            let result = await getSettings.execute()
            guard !Task.isCancelled else { return }
            switch result {
            case let .success(entity):
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                reduce {
                    $0.settings = entity
                    $0.appVersion = version
                    $0.buildNumber = build
                }
                showContent()

                // 1. Bootstrap gọi ngầm ko cần show loading dialog, không load tất cả translations.
                if let getAvailableLanguages {
                    let langsResult = await getAvailableLanguages.execute()
                    if !Task.isCancelled, case let .success(langs) = langsResult, !langs.isEmpty {
                        reduce { $0.settings.availableLanguages = langs }
                    }
                }
            case let .error(appError):
                handleError(appError)
            case .loading:
                break
            }
        }
    }

    private func selectLanguage(_ code: String) {
        reduce {
            $0.isLanguagePickerPresented = false
            $0.isSaving = true
        }

        guard let changeLanguage else {
            mutate { $0.language = code }
            return
        }

        launch(Self.languageEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            var isCached = AvailableLanguage.isDefaultOrBundled(code)
            if !isCached, let checkLanguageCached {
                isCached = await checkLanguageCached(code)
            }

            if isCached {
                // 2. Nếu có cached => Apply luôn, không show loading dialog.
                mutate { $0.language = code }
                reduce {
                    if let appLoc = self.localizationService as? AppLocalizationManager {
                        $0.translations = appLoc.dynamicOverrides
                    }
                    $0.isLoadingLanguage = false
                }
            } else {
                // 3. Nếu chưa có cached => Show loading dialog trong lúc call API.
                reduce {
                    $0.isLoadingLanguage = true
                }
            }

            // Gọi ngầm delta update (nếu cached) hoặc call API tải translations (nếu chưa cached)
            for await status in changeLanguage(code) {
                guard !Task.isCancelled else { return }
                handleLanguageSyncStatus(status, code: code, isCached: isCached)
            }
        }
    }

    private func handleLanguageSyncStatus(
        _ status: LanguageSyncStatus,
        code: String,
        isCached: Bool
    ) {
        switch status {
        case .loading:
            if !isCached {
                reduce {
                    $0.isLoadingLanguage = true
                }
            }
        case .cachedApplied:
            reduce {
                $0.settings.language = code
                $0.isLoadingLanguage = false
                if let appLoc = self.localizationService as? AppLocalizationManager {
                    $0.translations = appLoc.dynamicOverrides
                }
            }
        case .success:
            if !isCached {
                // Xong API => Apply language cho trường hợp chưa cached
                mutate { $0.language = code }
            }
            // Apply ngầm translations ko loading dialog sau đó (cho cả cached delta update và uncached API)
            reduce {
                if let appLoc = self.localizationService as? AppLocalizationManager {
                    $0.translations = appLoc.dynamicOverrides
                }
                $0.isLoadingLanguage = false
            }
        case let .error(appError):
            reduce {
                $0.isLoadingLanguage = false
                $0.isSaving = false
            }
            emit(.languageChangeFailed(appError.message))
        }
    }

    /// Applies `change` to `settings` optimistically, flags `isSaving`, then runs
    /// the shared `"save"` effect against a snapshot taken *before* the change.
    private func mutate(_ change: (inout SettingsEntity) -> Void) {
        let snapshot = uiState.settings
        reduce {
            change(&$0.settings)
            $0.isSaving = true
        }
        persist(revertingTo: snapshot)
    }

    private func persist(revertingTo snapshot: SettingsEntity) {
        launch(Self.saveEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }
            let result = await saveSettings.execute(uiState.settings)
            guard !Task.isCancelled else { return }
            reduce { $0.isSaving = false }
            if case let .error(appError) = result {
                reduce { $0.settings = snapshot }
                emit(.saveFailed(appError.message))
            }
        }
    }
}

@MainActor
final class NoOpLocalizationService: LocalizationService {
    var currentLanguageCode: String = "en"
    func setLocale(code: String) {
        currentLanguageCode = code
    }

    func applyDynamicTranslations(_: [String: String], languageCode _: String) {}
}
