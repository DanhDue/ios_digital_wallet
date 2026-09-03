import Combine
import Platform
import XCTest
@testable import Shell

/// The risk area (Testing tier A): visibility events published on a tab change
/// must be ORDERED old→new, and the `@Published` `uiState` sequence must be
/// `[initial, result]`. All recorders subscribe BEFORE the dispatch.
@MainActor
final class TabVisibilityEmissionTests: XCTestCase {
    func testSwitchingTabsPublishesExactlyOldFalseThenNewTrue() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(1))

        XCTAssertEqual(visibility.values, [
            VisibilityChange(tab: 2, visible: false),
            VisibilityChange(tab: 1, visible: true),
        ])
    }

    func testUiStatePublishedEmitsInitialThenResultInOrder() {
        let env = ShellTestEnv()
        let states = Recorder(env.sut.$uiState.map(\.selectedTab))

        env.sut.dispatch(.selectTab(0))

        XCTAssertEqual(states.values, [2, 0])
    }

    func testThreeRapidSwitchesFormAConsistentOldToNewChainWithNoGaps() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(0))
        env.sut.dispatch(.selectTab(1))
        env.sut.dispatch(.selectTab(2))

        let values = visibility.values
        XCTAssertEqual(values, [
            VisibilityChange(tab: 2, visible: false),
            VisibilityChange(tab: 0, visible: true),
            VisibilityChange(tab: 0, visible: false),
            VisibilityChange(tab: 1, visible: true),
            VisibilityChange(tab: 1, visible: false),
            VisibilityChange(tab: 2, visible: true),
        ])

        // Structural: pairs are (prev,false)(new,true); the `true` of one pair
        // and the `false` of the next name the same tab — no gap in the chain.
        for start in stride(from: 0, to: values.count, by: 2) {
            XCTAssertFalse(values[start].isVisible, "pair opens with a hide")
            XCTAssertTrue(values[start + 1].isVisible, "pair closes with a show")
            if start + 2 < values.count {
                XCTAssertEqual(values[start + 1].tabIndex, values[start + 2].tabIndex, "chain has no gap")
            }
        }
    }

    func testReTapPublishesNoVisibilityEvents() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(2))

        XCTAssertTrue(visibility.values.isEmpty)
    }

    func testOutOfRangeDispatchPublishesNoVisibilityEvents() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(7))

        XCTAssertTrue(visibility.values.isEmpty)
    }
}
