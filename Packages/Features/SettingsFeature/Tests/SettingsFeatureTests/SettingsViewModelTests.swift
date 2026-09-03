import Core
import XCTest
@testable import SettingsFeature

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

    // MARK: Helpers

    private func primeContent(_ env: SettingsEnv) async {
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }
    }
}
