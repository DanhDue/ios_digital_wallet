import Combine
import Platform
import XCTest
@testable import Shell

/// §9A category 7: `onClear()` empties `cancellables` / `effectTasks`, and no
/// bus emission follows.
@MainActor
final class TeardownTests: XCTestCase {
    func testOnClearEmptiesCancellablesAndEffectTasks() {
        let env = ShellTestEnv()
        env.sut.$uiState.sink { _ in }.store(in: &env.sut.cancellables)
        XCTAssertEqual(env.sut.cancellables.count, 1)

        env.sut.onClear()

        XCTAssertTrue(env.sut.cancellables.isEmpty)
        XCTAssertTrue(env.sut.effectTasks.isEmpty)
    }

    func testNoBusEmissionIsDeliveredAfterOnClear() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(0))
        XCTAssertEqual(visibility.count, 2)

        env.sut.onClear()

        XCTAssertEqual(visibility.count, 2, "onClear itself publishes nothing to the bus")
    }

    func testViewModelIsNotRetainedAfterScopeExit() {
        weak var weakSUT: ShellViewModel?

        autoreleasepool {
            let router = AppRouter(tabCount: 3, initialTab: 2)
            let sut = ShellViewModel(
                config: ShellConfig(tabCount: 3, initialTab: 2),
                router: router,
                eventBus: AppEventBus()
            )
            weakSUT = sut
            sut.dispatch(.selectTab(0))
            sut.onClear()
        }

        XCTAssertNil(weakSUT, "no retain cycle keeps the shell ViewModel alive")
    }
}
