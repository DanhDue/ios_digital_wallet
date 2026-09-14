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
        let targetTab = 0

        env.sut.dispatch(.selectTab(targetTab))

        XCTAssertEqual(visibility.values, [
            VisibilityChange(tab: env.config.initialTab, visible: false),
            VisibilityChange(tab: targetTab, visible: true),
        ])
    }

    func testUiStatePublishedEmitsInitialThenResultInOrder() {
        let env = ShellTestEnv()
        let states = Recorder(env.sut.$uiState.map(\.selectedTab))

        env.sut.dispatch(.selectTab(0))

        XCTAssertEqual(states.values, [env.config.initialTab, 0])
    }

    func testThreeRapidSwitchesFormAConsistentOldToNewChainWithNoGaps() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        let otherTab = (env.config.initialTab == 0) ? 1 : 0
        env.sut.dispatch(.selectTab(otherTab))
        env.sut.dispatch(.selectTab(env.config.initialTab))

        let values = visibility.values
        XCTAssertEqual(values, [
            VisibilityChange(tab: env.config.initialTab, visible: false),
            VisibilityChange(tab: otherTab, visible: true),
            VisibilityChange(tab: otherTab, visible: false),
            VisibilityChange(tab: env.config.initialTab, visible: true),
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

        env.sut.dispatch(.selectTab(env.config.initialTab))

        XCTAssertTrue(visibility.values.isEmpty)
    }

    func testOutOfRangeDispatchPublishesNoVisibilityEvents() {
        let env = ShellTestEnv()
        let visibility = env.bus.visibilityRecorder()

        env.sut.dispatch(.selectTab(7))

        XCTAssertTrue(visibility.values.isEmpty)
    }
}
