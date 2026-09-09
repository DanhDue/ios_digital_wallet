import Core
import XCTest
@testable import Settings

@MainActor
final class SettingsViewModelTests: XCTestCase {
    // MARK: onAppear

    func testOnAppearLoadsStoredSettingsAndShowsContent() async {
        let env = SettingsEnv()
        let stored = SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false)
        env.repo.loadResult = .success(stored)

        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.sut.viewState.tag, "content")
        XCTAssertEqual(env.sut.uiState.settings, stored)
        XCTAssertEqual(env.repo.loadCallCount, 1)
    }

    func testOnAppearWithNoStoredSettingsUsesDefaultEntityAndShowsContent() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)

        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.sut.viewState.tag, "content")
        XCTAssertEqual(env.sut.uiState.settings, .default)
    }

    func testOnAppearThroughRealRepositoryWithCorruptCacheYieldsDefaultPlusLoggerError() async {
        let logger = SpyLogger()
        let cache = InMemoryCacheStore(logger: logger)
        cache.seedRaw(Data("{ not valid settings json".utf8), key: "settings")
        let repository = SettingsRepositoryImpl(cache: cache, logger: logger)
        let sut = SettingsViewModel(repository: repository)

        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "content" }

        XCTAssertEqual(sut.viewState.tag, "content")
        XCTAssertEqual(sut.uiState.settings, .default)
        XCTAssertFalse(logger.errorMessages.isEmpty, "a decode failure must be logged at .error")
    }

    func testOnAppearThroughRealRepositoryWithMissingCacheYieldsDefaultNoCrash() async {
        let logger = SpyLogger()
        let cache = InMemoryCacheStore(logger: logger)
        let sut = SettingsViewModel(repository: SettingsRepositoryImpl(cache: cache, logger: logger))

        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "content" }

        XCTAssertEqual(sut.uiState.settings, .default)
        XCTAssertTrue(logger.errorMessages.isEmpty, "a genuinely-absent key is not an error")
    }

    func testOnAppearBootstrapRunsSilentlyInBackgroundWithoutLoadingDialog() async {
        let env = SettingsEnv()
        let newLangs = [
            AvailableLanguage(languageCode: "fr", languageName: "French", isDefault: false, isActive: true),
        ]
        let gate = AsyncGate()
        env.repo.loadGate = gate
        env.repo.availableLanguagesResult = .success(newLangs)

        env.sut.dispatch(.onAppear)

        await gate.open()
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.sut.viewState.tag, "content")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage, "bootstrap must never show loading dialog")

        await poll { env.sut.uiState.settings.availableLanguages == newLangs }
        XCTAssertEqual(env.sut.uiState.settings.availableLanguages, newLangs)
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage)
    }

    func testSelectLanguageWithCachedTranslationsAppliesImmediatelyAndRunsDeltaSilently() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.repo.cachedLanguages = ["ja"]

        let gate = AsyncGate()
        env.repo.localizationOverridesGate = gate
        env.repo.localizationOverridesResult = .success(
            TranslationOverride(version: "1.0.1", translations: ["settings.title": "設定 (Delta)"], checksum: "abc")
        )

        // 1. Select cached language
        env.sut.dispatch(.selectLanguage("ja"))

        // 2. Applies immediately without loading dialog
        await poll { env.sut.uiState.settings.language == "ja" }
        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage, "cached language selection must NOT show loading dialog")

        // 3. Background delta update finishes and applies silently
        await gate.open()
        await poll { env.localizationService.appliedTranslations.last?.translations["settings.title"] == "設定 (Delta)" }
        XCTAssertEqual(env.localizationService.appliedTranslations.last?.translations["settings.title"], "設定 (Delta)")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage)
    }

    func testSelectLanguageWithUncachedTranslationsShowsLoadingDialogUntilAPICompletes() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.repo.cachedLanguages = [] // Not cached

        let gate = AsyncGate()
        env.repo.localizationOverridesGate = gate
        env.repo.localizationOverridesResult = .success(
            TranslationOverride(version: "1.0.1", translations: ["settings.title": "Paramètres"], checksum: "abc")
        )

        // 1. Select uncached language
        env.sut.dispatch(.selectLanguage("fr"))

        // 2. Shows loading dialog while calling API
        await poll { env.sut.uiState.isLoadingLanguage }
        XCTAssertTrue(env.sut.uiState.isLoadingLanguage, "must show loading dialog when language is not cached")

        // 3. API finishes -> applies language & dismisses dialog
        await gate.open()
        await poll { env.sut.uiState.settings.language == "fr" && !env.sut.uiState.isLoadingLanguage }

        XCTAssertEqual(env.sut.uiState.settings.language, "fr")
        XCTAssertEqual(env.localizationService.appliedTranslations.last?.translations["settings.title"], "Paramètres")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage, "loading dialog must be dismissed after API finishes")
    }

    func testSelectLanguageWithUncachedJapaneseShowsLoadingDialogUntilAPICompletes() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.repo.cachedLanguages = [] // Fresh reinstall: no cached Japanese translations

        let gate = AsyncGate()
        env.repo.localizationOverridesGate = gate
        env.repo.localizationOverridesResult = .success(
            TranslationOverride(version: "1.0.1", translations: ["settings.title": "設定"], checksum: "ja-hash")
        )

        // 1. User clicks Japanese in picker
        env.sut.dispatch(.selectLanguage("ja"))

        // 2. Shows loading dialog while calling API
        await poll { env.sut.uiState.isLoadingLanguage }
        XCTAssertTrue(env.sut.uiState.isLoadingLanguage, "must show loading dialog when Japanese is not cached")

        // 3. API finishes -> applies Japanese & dismisses dialog
        await gate.open()
        await poll { env.sut.uiState.settings.language == "ja" && !env.sut.uiState.isLoadingLanguage }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertEqual(env.localizationService.appliedTranslations.last?.translations["settings.title"], "設定")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage, "loading dialog must be dismissed after API finishes")
    }

    func testAvailableLanguageIsDefaultOrBundled() {
        XCTAssertTrue(AvailableLanguage.isDefaultOrBundled("en"))
        XCTAssertTrue(AvailableLanguage.isDefaultOrBundled("en_US"))
        XCTAssertTrue(AvailableLanguage.isDefaultOrBundled("vi"))
        XCTAssertTrue(AvailableLanguage.isDefaultOrBundled("vi_VN"))
        XCTAssertFalse(AvailableLanguage.isDefaultOrBundled("ja"))
        XCTAssertFalse(AvailableLanguage.isDefaultOrBundled("ja_JP"))
        XCTAssertFalse(AvailableLanguage.isDefaultOrBundled("ko"))
        XCTAssertFalse(AvailableLanguage.isDefaultOrBundled("ko_KR"))
    }

    // MARK: Toggle state transitions

    func testToggleDarkModeFlipsFlagAndClearsIsSavingOnSuccess() async {
        let env = SettingsEnv()
        await primeContent(env)
        let before = env.sut.uiState.settings.isDarkMode

        env.sut.dispatch(.toggleDarkMode)
        XCTAssertEqual(env.sut.uiState.settings.isDarkMode, !before)
        XCTAssertTrue(env.sut.uiState.isSaving, "isSaving is true synchronously with the optimistic reduce")

        await poll { env.sut.uiState.isSaving == false }
        XCTAssertFalse(env.sut.uiState.isSaving)
        XCTAssertEqual(env.repo.savedEntities.last?.isDarkMode, !before)
    }

    func testToggleNotificationsTogglesAndPersists() async {
        let env = SettingsEnv()
        await primeContent(env)
        let before = env.sut.uiState.settings.notificationsEnabled

        env.sut.dispatch(.toggleNotifications)
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(env.sut.uiState.settings.notificationsEnabled, !before)
        XCTAssertEqual(env.repo.savedEntities.last?.notificationsEnabled, !before)
    }

    func testViewStateStaysContentThroughoutASuccessfulToggle() async {
        let env = SettingsEnv()
        await primeContent(env)
        let recorder = Recorder(env.sut.$viewState.map(\.tag))

        env.sut.dispatch(.toggleDarkMode)
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(recorder.values, ["content"], "a persist round-trip never flips viewState to loading/error")
    }

    // MARK: selectLanguage validation matrix

    func testSelectLanguageWithEmptyStringIsRejected() async {
        let env = SettingsEnv()
        await primeContent(env)
        let snapshot = env.sut.uiState

        env.sut.dispatch(.selectLanguage(""))
        await settle()

        XCTAssertEqual(env.sut.uiState, snapshot, "empty tag leaves state untouched")
        XCTAssertEqual(env.repo.saveCallCount, 0)
    }

    func testSelectLanguageWithTwoLetterTagPersists() async {
        let env = SettingsEnv()
        await primeContent(env)

        env.sut.dispatch(.selectLanguage("ja"))
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertEqual(env.repo.savedEntities.last?.language, "ja")
    }

    func testSelectLanguageWithLongTagPersists() async {
        let env = SettingsEnv()
        await primeContent(env)
        let long = "zh-Hans-CN-x-custom-very-long-tag"

        env.sut.dispatch(.selectLanguage(long))
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(env.sut.uiState.settings.language, long)
        XCTAssertEqual(env.repo.savedEntities.last?.language, long)
    }

    // MARK: ThemeManager & New Presentation Features

    func testSelectLanguageWithCachedLanguageAppliesImmediately() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.repo.cachedLanguages = ["ja"]

        env.sut.dispatch(.showLanguagePicker(true))
        XCTAssertTrue(env.sut.uiState.isLanguagePickerPresented)

        env.sut.dispatch(.selectLanguage("ja"))
        await poll { env.sut.uiState.settings.language == "ja" && !env.sut.uiState.isSaving }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage)
        XCTAssertFalse(env.sut.uiState.isLanguagePickerPresented)
    }

    func testSelectLanguageWithUncachedLanguageSetsIsLoadingLanguageUntilComplete() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.repo.cachedLanguages = []

        env.sut.dispatch(.selectLanguage("fr"))
        await poll { env.sut.uiState.settings.language == "fr" && !env.sut.uiState.isSaving }

        XCTAssertEqual(env.sut.uiState.settings.language, "fr")
        XCTAssertFalse(env.sut.uiState.isLoadingLanguage)
    }

    func testRapidSelectLanguageCallsCoalesceAndKeepFinalSelection() async {
        let env = SettingsEnv()
        await primeContent(env)

        env.sut.dispatch(.selectLanguage("vi"))
        env.sut.dispatch(.selectLanguage("ja"))
        await poll { env.sut.uiState.settings.language == "ja" && !env.sut.uiState.isSaving }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
    }

    func testShowLanguagePickerUpdatesIsLanguagePickerPresented() async {
        let env = SettingsEnv()
        await primeContent(env)

        env.sut.dispatch(.showLanguagePicker(true))
        XCTAssertTrue(env.sut.uiState.isLanguagePickerPresented)

        env.sut.dispatch(.showLanguagePicker(false))
        XCTAssertFalse(env.sut.uiState.isLanguagePickerPresented)
    }

    func testToggleDeveloperModeUpdatesIsDeveloperModeEnabled() async {
        let env = SettingsEnv()
        await primeContent(env)

        env.sut.dispatch(.toggleDeveloperMode(true))
        XCTAssertTrue(env.sut.uiState.isDeveloperModeEnabled)

        env.sut.dispatch(.toggleDeveloperMode(false))
        XCTAssertFalse(env.sut.uiState.isDeveloperModeEnabled)
    }

    func testOnAppearLoadsAvailableLanguagesAndAppVersion() async {
        let env = SettingsEnv()
        let customLangs = [
            AvailableLanguage(languageCode: "ko", languageName: "한국어", isDefault: false, isActive: true),
        ]
        env.repo.availableLanguagesResult = .success(customLangs)

        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.sut.uiState.settings.availableLanguages, customLangs)
        XCTAssertFalse(env.sut.uiState.appVersion.isEmpty)
        XCTAssertFalse(env.sut.uiState.buildNumber.isEmpty)
    }

    func testSelectLanguageUpdatesDynamicTranslationsAndResolvesViaTr() async {
        let env = SettingsEnv()
        await primeContent(env)

        env.sut.dispatch(.selectLanguage("ja"))
        await poll { env.localizationService.setLocaleCalls.last == "ja" }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertEqual(env.localizationService.setLocaleCalls.last, "ja")
    }

    func testBackgroundLanguageRevalidationDoesNotDismissReopenedLanguagePicker() async {
        let env = SettingsEnv()
        await primeContent(env)
        env.localizationService.currentLanguageCode = "vi"
        env.repo.cachedLanguages = []
        let gate = AsyncGate()
        env.repo.localizationOverridesGate = gate

        // 1. User opens picker and selects "fr"
        env.sut.dispatch(.showLanguagePicker(true))
        XCTAssertTrue(env.sut.uiState.isLanguagePickerPresented)

        env.sut.dispatch(.selectLanguage("fr"))
        XCTAssertFalse(env.sut.uiState.isLanguagePickerPresented, "sheet must dismiss immediately upon selection")

        // 2. User quickly reopens picker while background network call is in flight
        env.sut.dispatch(.showLanguagePicker(true))
        XCTAssertTrue(env.sut.uiState.isLanguagePickerPresented)

        // 3. Background network call finishes
        await gate.open()
        await poll { env.sut.uiState.settings.language == "fr" && !env.sut.uiState.isLoadingLanguage }

        // 4. Picker must REMAIN presented, NOT dismissed by background revalidation
        XCTAssertTrue(env.sut.uiState.isLanguagePickerPresented, "picker must stay open despite background sync finish")

        // 5. Subsequent user selection dismisses picker
        env.sut.dispatch(.selectLanguage("ja"))
        XCTAssertFalse(env.sut.uiState.isLanguagePickerPresented)
    }

    // MARK: Helpers

    private func primeContent(_ env: SettingsEnv) async {
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }
    }
}
