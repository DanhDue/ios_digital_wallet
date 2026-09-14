import Platform
import XCTest
@testable import Shell

/// Initial tab; `selectTab` different vs. same; out-of-range ignored;
/// rapid-switch final state. (BDD: happy path + state transitions + race.)
@MainActor
final class ShellViewModelTests: XCTestCase {
    // MARK: Cold start

    func testColdStartSelectsConfiguredInitialTabInStateAndRouter() {
        let config = ShellConfig()
        let env = ShellTestEnv(config: config, routerInitialTab: 0)

        XCTAssertEqual(env.sut.uiState.selectedTab, config.initialTab)
        XCTAssertEqual(
            env.router.selectedTab,
            config.initialTab,
            "the shell syncs the router to ShellConfig.initialTab"
        )
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

        env.sut.dispatch(.selectTab(env.config.tabCount))

        XCTAssertEqual(env.sut.uiState.selectedTab, env.config.initialTab)
        XCTAssertEqual(env.router.selectedTab, env.config.initialTab)
        XCTAssertTrue(visibility.values.isEmpty)
    }

    func testIndexFarAboveRangeIsIgnored() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(99))

        XCTAssertEqual(env.sut.uiState.selectedTab, env.config.initialTab)
    }

    func testNegativeIndexIsIgnored() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(-1))

        XCTAssertEqual(env.sut.uiState.selectedTab, env.config.initialTab)
        XCTAssertEqual(env.router.selectedTab, env.config.initialTab)
    }

    // MARK: Rapid switch

    func testThreeRapidDistinctDispatchesEndAtTheLastIndex() {
        let env = ShellTestEnv()
        let lastIndex = env.config.tabCount - 1

        for tabIndex in 0 ... lastIndex {
            env.sut.dispatch(.selectTab(tabIndex))
        }

        XCTAssertEqual(env.sut.uiState.selectedTab, lastIndex)
        XCTAssertEqual(env.router.selectedTab, lastIndex)
    }

    // MARK: Re-tap keeps the index

    func testReTappingTheActiveTabDoesNotChangeSelectedTab() {
        let env = ShellTestEnv()

        env.sut.dispatch(.selectTab(env.config.initialTab))

        XCTAssertEqual(env.sut.uiState.selectedTab, env.config.initialTab)
    }
}
