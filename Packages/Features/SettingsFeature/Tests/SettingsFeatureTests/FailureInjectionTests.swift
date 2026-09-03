import Combine
import Core
import XCTest
@testable import SettingsFeature

@MainActor
final class FailureInjectionTests: XCTestCase {
    func testFailedSaveRevertsTheOptimisticToggleAndEmitsSaveFailedExactlyOnce() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        var events: [SettingsEvent] = []
        let token = env.sut.eventSubject.sink { events.append($0) }
        env.repo.saveResult = .error(AppError(code: "save.fail", message: "disk full"))
        let before = env.sut.uiState.settings

        env.sut.dispatch(.toggleDarkMode)
        XCTAssertEqual(env.sut.uiState.settings.isDarkMode, !before.isDarkMode, "optimistic flip happens first")

        await poll { !events.isEmpty }
        await settle()

        XCTAssertEqual(env.sut.uiState.settings, before, "a failed save reverts to the pre-action snapshot")
        XCTAssertFalse(env.sut.uiState.isSaving)
        XCTAssertEqual(events, [.saveFailed("disk full")], "exactly one .saveFailed")
        token.cancel()
    }

    func testFailedLoadShowsErrorAndRetryViaOnAppearRecovers() async {
        let env = SettingsEnv()
        env.repo.loadResult = .error(AppError(code: "load.fail", message: "offline"))

        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "error" }
        XCTAssertEqual((env.sut.viewState.errorValue as? AppError)?.message, "offline")

        env.repo.loadResult = .success(SettingsEntity(isDarkMode: true, language: "ja", notificationsEnabled: false))
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.sut.uiState.settings.language, "ja")
        XCTAssertEqual(env.repo.loadCallCount, 2)
    }

    func testFailedSaveKeepsScreenOnContentThroughout() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        let recorder = Recorder(env.sut.$viewState.map(\.tag).removeDuplicates())
        env.repo.saveResult = .error(AppError(code: "save.fail", message: "x"))

        env.sut.dispatch(.toggleNotifications)
        await poll { env.sut.uiState.isSaving == false }
        await settle()

        XCTAssertEqual(recorder.values, ["content"])
    }
}
