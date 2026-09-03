import Combine
import Platform
import XCTest
@testable import Shell

/// Re-tapping the active tab: `router.popToRoot(inTab:)` + `emit(.scrollToTop)`,
/// with NO `reduce` and NO bus publish (BDD: state transitions).
@MainActor
final class ReTapTests: XCTestCase {
    func testReTapPopsActiveTabToRootAndEmitsScrollToTopWithNoStateOrBusChange() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 2)
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 2)
        XCTAssertEqual(router.tabPaths[2].count, 2)

        let bus = AppEventBus()
        let sut = ShellViewModel(config: ShellConfig(tabCount: 3, initialTab: 2), router: router, eventBus: bus)
        let events = Recorder(sut.eventSubject)
        let visibility = bus.visibilityRecorder()
        let states = Recorder(sut.$uiState.map(\.selectedTab))

        sut.dispatch(.selectTab(2))

        XCTAssertEqual(router.tabPaths[2].count, 0, "popToRoot(inTab: 2) ran")
        XCTAssertEqual(sut.uiState.selectedTab, 2)
        XCTAssertEqual(states.values, [2], "no reduce on re-tap")
        XCTAssertTrue(visibility.values.isEmpty, "no bus publish on re-tap")
        XCTAssertEqual(events.values, [.scrollToTop(tab: 2)])
    }

    func testReTapLeavesOtherTabsStacksUntouched() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        router.navigate(to: AppRoutes.ScannerRoot(), inTab: 1)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: ShellConfig(tabCount: 3, initialTab: 2), router: router, eventBus: bus)

        sut.dispatch(.selectTab(2))

        XCTAssertEqual(router.tabPaths[1].count, 1, "only the re-tapped tab is popped")
    }

    func testSwitchingToADifferentTabDoesNotEmitScrollToTop() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: ShellConfig(tabCount: 3, initialTab: 2), router: router, eventBus: bus)
        let events = Recorder(sut.eventSubject)

        sut.dispatch(.selectTab(0))

        XCTAssertTrue(events.values.isEmpty)
    }

    func testReTapOnANonInitialTabAfterSwitching() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: ShellConfig(tabCount: 3, initialTab: 2), router: router, eventBus: bus)
        sut.dispatch(.selectTab(0))
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 0)
        let events = Recorder(sut.eventSubject)

        sut.dispatch(.selectTab(0))

        XCTAssertEqual(router.tabPaths[0].count, 0)
        XCTAssertEqual(events.values, [.scrollToTop(tab: 0)])
    }
}
