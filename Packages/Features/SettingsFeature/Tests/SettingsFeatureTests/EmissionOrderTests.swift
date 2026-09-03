import Core
import XCTest
@testable import SettingsFeature

/// Exact `@Published` emission *sequences* (arrays), recorders subscribed BEFORE
/// the first dispatch.
@MainActor
final class EmissionOrderTests: XCTestCase {
    func testViewStateSequenceForSuccessfulLoadIsLoadingThenContent() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        let recorder = Recorder(env.sut.$viewState.map(\.tag).removeDuplicates())

        env.sut.dispatch(.onAppear)
        await poll { recorder.values.contains("content") }

        XCTAssertEqual(recorder.values, ["loading", "content"])
    }

    func testViewStateSequenceForFailedLoadIsLoadingThenError() async {
        let env = SettingsEnv()
        env.repo.loadResult = .error(AppError(code: "load.fail", message: "nope"))
        let recorder = Recorder(env.sut.$viewState.map(\.tag).removeDuplicates())

        env.sut.dispatch(.onAppear)
        await poll { recorder.values.contains("error") }

        XCTAssertEqual(recorder.values, ["loading", "error"])
    }

    func testSuccessfulToggleEmitsUiStateBeforeThenOptimisticOnly() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        // Project the user-visible settings value; a successful toggle moves it
        // before -> optimistic and never again (no revert). `isSaving` churn is
        // a separate field and out of scope for this assertion.
        let recorder = Recorder(env.sut.$uiState.map(\.settings).removeDuplicates())
        let optimistic = SettingsEntity(isDarkMode: true, language: "en", notificationsEnabled: true)

        env.sut.dispatch(.toggleDarkMode)
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(recorder.values, [.default, optimistic])
    }

    func testOnAppearFailureThenRetrySucceedsRecoversToContent() async {
        let env = SettingsEnv()
        env.repo.loadResult = .error(AppError(code: "load.fail", message: "nope"))
        let recorder = Recorder(env.sut.$viewState.map(\.tag).removeDuplicates())

        env.sut.dispatch(.onAppear)
        await poll { recorder.values.last == "error" }

        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { recorder.values.last == "content" }

        XCTAssertEqual(recorder.values, ["loading", "error", "loading", "content"])
    }
}
