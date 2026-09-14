import Combine
import Platform
import XCTest
@testable import Shell

/// Re-tapping the active tab: `router.popToRoot(inTab:)` + `emit(.scrollToTop)`,
/// with NO `reduce` and NO bus publish (BDD: state transitions).
@MainActor
final class ReTapTests: XCTestCase {
    func testReTapPopsActiveTabToRootAndEmitsScrollToTopWithNoStateOrBusChange() {
        let config = ShellConfig()
        let tab = config.initialTab
        let router = AppRouter(tabCount: config.tabCount, initialTab: tab)
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: tab)
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: tab)
        XCTAssertEqual(router.tabPaths[tab].count, 2)

        let bus = AppEventBus()
        let sut = ShellViewModel(config: config, router: router, eventBus: bus)
        let events = Recorder(sut.eventSubject)
        let visibility = bus.visibilityRecorder()
        let states = Recorder(sut.$uiState.map(\.selectedTab))

        sut.dispatch(.selectTab(tab))

        XCTAssertEqual(router.tabPaths[tab].count, 0, "popToRoot(inTab: \(tab)) ran")
        XCTAssertEqual(sut.uiState.selectedTab, tab)
        XCTAssertEqual(states.values, [tab], "no reduce on re-tap")
        XCTAssertTrue(visibility.values.isEmpty, "no bus publish on re-tap")
        XCTAssertEqual(events.values, [.scrollToTop(tab: tab)])
    }

    func testReTapLeavesOtherTabsStacksUntouched() {
        let config = ShellConfig()
        let tab = config.initialTab
        let router = AppRouter(tabCount: config.tabCount, initialTab: tab)
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 0)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: config, router: router, eventBus: bus)

        sut.dispatch(.selectTab(tab))

        XCTAssertEqual(router.tabPaths[0].count, 1, "only the re-tapped tab is popped")
    }

    func testSwitchingToADifferentTabDoesNotEmitScrollToTop() {
        let config = ShellConfig()
        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: config, router: router, eventBus: bus)
        let events = Recorder(sut.eventSubject)

        sut.dispatch(.selectTab(0))

        XCTAssertTrue(events.values.isEmpty)
    }

    func testReTapOnANonInitialTabAfterSwitching() {
        let config = ShellConfig()
        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: config, router: router, eventBus: bus)
        sut.dispatch(.selectTab(0))
        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 0)
        let events = Recorder(sut.eventSubject)

        sut.dispatch(.selectTab(0))

        XCTAssertEqual(router.tabPaths[0].count, 0)
        XCTAssertEqual(events.values, [.scrollToTop(tab: 0)])
    }
}
