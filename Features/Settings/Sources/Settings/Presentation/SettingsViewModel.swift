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

    @Injected(\.settingsGetSettingsUseCase) private var getSettings: GetSettingsUseCase
    @Injected(\.settingsSaveSettingsUseCase) private var saveSettings: SaveSettingsUseCase
    @Injected(\.settingsGetAvailableLanguagesUseCase) private var getAvailableLanguages: GetAvailableLanguagesUseCase
    @Injected(\.settingsCheckLanguageCachedUseCase) private var checkLanguageCached: CheckLanguageCachedUseCase
    @Injected(\.settingsChangeLanguage) private var changeLanguage: ChangeLanguageUseCase

    /// Designated initializer.
    /// In production: call `SettingsViewModel()` to auto-resolve all dependencies via Factory.
    /// In testing / previews: pass mock UseCases or services directly to override.
    public init(
        getSettings: GetSettingsUseCase? = nil,
        saveSettings: SaveSettingsUseCase? = nil,
        getAvailableLanguages: GetAvailableLanguagesUseCase? = nil,
        checkLanguageCached: CheckLanguageCachedUseCase? = nil,
        changeLanguage: ChangeLanguageUseCase? = nil
    ) {
        super.init(initialState: SettingsState(settings: .default))

        if let getSettings {
            _getSettings.wrappedValue = getSettings
        }
        if let saveSettings {
            _saveSettings.wrappedValue = saveSettings
        }
        if let getAvailableLanguages {
            _getAvailableLanguages.wrappedValue = getAvailableLanguages
        }
        if let checkLanguageCached {
            _checkLanguageCached.wrappedValue = checkLanguageCached
        }
        if let changeLanguage {
            _changeLanguage.wrappedValue = changeLanguage
        }
    }

    override public func onAction(_ action: SettingsAction) {
        switch action {
        case .onAppear:
            load()
        case .toggleDarkMode:
            let newMode = !uiState.settings.isDarkMode
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

            let result = await getSettings()
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
                let langsResult = await getAvailableLanguages()
                if !Task.isCancelled, case let .success(langs) = langsResult, !langs.isEmpty {
                    reduce { $0.settings.availableLanguages = langs }
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

        launch(Self.languageEffect) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            var isCached = AvailableLanguage.isDefaultOrBundled(code)
            if !isCached {
                isCached = await checkLanguageCached(code)
            }

            if isCached {
                // 2. Nếu có cached => Apply luôn, không show loading dialog.
                mutate { $0.language = code }
                reduce {
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
            }
        case .success:
            if !isCached {
                // Xong API => Apply language cho trường hợp chưa cached
                mutate { $0.language = code }
            }
            // Apply ngầm translations ko loading dialog sau đó (cho cả cached delta update và uncached API)
            reduce {
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
            let result = await saveSettings(uiState.settings)
            guard !Task.isCancelled else { return }
            reduce { $0.isSaving = false }
            if case let .error(appError) = result {
                reduce { $0.settings = snapshot }
                emit(.saveFailed(appError.message))
            }
        }
    }
}
