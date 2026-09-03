import Platform
import XCTest
@testable import Shell

/// Initial tab; `selectTab` different vs. same; out-of-range ignored;
/// rapid-switch final state. (BDD: happy path + state transitions + race.)
@MainActor
final class ShellViewModelTests: XCTestCase {
    // MARK: Cold start

    func testColdStartSelectsConfiguredInitialTabInStateAndRouter() {
        let env = ShellTestEnv(initialTab: 2, routerInitialTab: 0)

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
        XCTAssertEqual(env.router.selectedTab, 2, "the shell syncs the router to ShellConfig.initialTab")
    }

    // MARK: Switch to a different tab

    func testSelectingADifferentTabUpdatesStateAndRouter() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(0))

        XCTAssertEqual(env.sut.uiState.selectedTab, 0)
        XCTAssertEqual(env.router.selectedTab, 0)
    }

    // MARK: Out-of-range

    func testIndexAtTabCountIsIgnored() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(3))

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
        XCTAssertEqual(env.router.selectedTab, 2)
        XCTAssertTrue(visibility.values.isEmpty)
    }

    func testIndexFarAboveRangeIsIgnored() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(99))

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
    }

    func testNegativeIndexIsIgnored() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(-1))

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
        XCTAssertEqual(env.router.selectedTab, 2)
    }

    // MARK: Rapid switch

    func testThreeRapidDistinctDispatchesEndAtTheLastIndex() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(0))
        env.sut.dispatch(.selectTab(1))
        env.sut.dispatch(.selectTab(2))

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
        XCTAssertEqual(env.router.selectedTab, 2)
    }

    // MARK: Re-tap keeps the index

    func testReTappingTheActiveTabDoesNotChangeSelectedTab() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(2))

        XCTAssertEqual(env.sut.uiState.selectedTab, 2)
    }
}
