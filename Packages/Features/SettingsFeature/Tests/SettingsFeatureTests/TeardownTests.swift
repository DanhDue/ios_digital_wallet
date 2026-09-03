import Combine
import Core
import XCTest
@testable import SettingsFeature

/// Source Spec §9A category 7: `onClear()` cancels every effect, empties
/// `cancellables`, and nothing is emitted afterwards.
@MainActor
final class TeardownTests: XCTestCase {
    func testOnClearEmptiesCancellablesAndEffectTasks() async {
        let env = SettingsEnv()
        env.sut.$uiState.sink { _ in }.store(in: &env.sut.cancellables)
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        env.sut.onClear()

        XCTAssertTrue(env.sut.cancellables.isEmpty)
        XCTAssertTrue(env.sut.effectTasks.isEmpty)
    }

    func testSaveInFlightWhenOnClearIsCalledIsCancelledAndNotPersisted() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        let gate = AsyncGate()
        env.repo.saveGate = gate
        env.sut.dispatch(.toggleDarkMode)
        await poll { env.repo.saveCallCount == 1 }

        env.sut.onClear()
        await gate.open() // release the parked save; it must observe cancellation
        await settle()

        XCTAssertTrue(env.sut.effectTasks.isEmpty)
        XCTAssertEqual(env.repo.savedEntities, [], "a cancelled save writes nothing")
    }

    func testNoEmissionAfterOnClear() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        env.sut.onClear()
        let uiRecorder = Recorder(env.sut.$uiState.map(\.settings))
        let eventRecorder = Recorder(env.sut.eventSubject)

        env.sut.dispatch(.toggleDarkMode)
        await settle()

        // The optimistic reduce still runs synchronously (dispatch is not gated
        // by onClear), but the "save" effect must not emit an event afterwards.
        XCTAssertTrue(eventRecorder.values.isEmpty, "no event after onClear")
        uiRecorder.stop()
        eventRecorder.stop()
    }

    func testViewModelIsNotRetainedAfterScopeExit() async {
        weak var weakSUT: SettingsViewModel?
        let repo = SpySettingsRepository()
        repo.loadResult = .success(.default)

        await autoreleaseScope {
            let sut = SettingsViewModel(repository: repo)
            weakSUT = sut
            sut.dispatch(.onAppear)
            await poll { sut.viewState.tag == "content" }
            sut.onClear()
        }

        XCTAssertNil(weakSUT, "no retain cycle keeps the ViewModel alive")
    }

    private func autoreleaseScope(_ body: () async -> Void) async {
        await body()
    }
}
