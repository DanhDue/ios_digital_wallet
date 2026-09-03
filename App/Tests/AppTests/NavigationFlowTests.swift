import Combine
import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

#if canImport(UIKit)
    import UIKit
#endif

/// Tier C — the §4.3 end-to-end navigation flow, driven through the *composed*
/// app (router + providers + shell built by `AppComposition`).
@MainActor
final class NavigationFlowTests: XCTestCase {
    // MARK: Selecting the Settings tab

    func testSelectingSettingsTabPublishesVisibilityAndResolvesTheSettingsProvider() throws {
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus)
        let recorder = Recorder(bus.on(ShellTabVisibilityChanged.self).map { TabVisibility($0) })

        // Cold start selects tab 2 with no event; move away then back so the
        // show/hide pair for tab 2 is observable.
        sut.shellViewModel.dispatch(.selectTab(0))
        sut.shellViewModel.dispatch(.selectTab(2))

        XCTAssertEqual(sut.router.selectedTab, 2)
        XCTAssertEqual(recorder.values.last, TabVisibility.make(tab: 2, visible: true))

        // AppRouter.destination(for: SettingsRoot()) resolves the SettingsFeature provider.
        let settingsProviders = sut.routeProviders.filter { $0.canHandle(AppRoutes.SettingsRoot()) }
        XCTAssertEqual(settingsProviders.count, 1)
        let resolved = try XCTUnwrap(settingsProviders.first)
        XCTAssertTrue(String(describing: type(of: resolved)).contains("SettingsRouteProvider"))
    }

    // MARK: Per-tab stack preservation

    func testDeepPushThenTabSwitchThenBackPreservesThePerTabStack() {
        let sut = AppComposition(eventBus: AppEventBus())

        sut.router.navigate(to: AppRoutes.SettingsRoot(), inTab: 2)
        XCTAssertEqual(sut.router.tabPaths[2].count, 1)

        sut.router.switchTab(0)
        sut.router.switchTab(2)

        XCTAssertEqual(sut.router.tabPaths[2].count, 1, "tab 2 still shows the pushed screen")
        XCTAssertEqual(sut.router.tabPaths[0].count, 0, "tab 0 keeps its own (empty) stack")
        XCTAssertEqual(sut.router.selectedTab, 2)
    }

    // MARK: Hosting the composed shell

    #if canImport(UIKit)
        func testHostingTheComposedShellRendersAndDefaultsToSettings() {
            let sut = AppComposition(eventBus: AppEventBus())

            let host = UIHostingController(rootView: RootView(composition: sut))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            XCTAssertNotNil(host.view)
            XCTAssertEqual(sut.router.selectedTab, 2, "Settings is the default-selected tab")
            XCTAssertEqual(sut.router.tabPaths.count, 3, "three tabs: Home / Scanner / Settings")
        }
    #endif
}

extension TabVisibility {
    static func make(tab: Int, visible: Bool) -> TabVisibility {
        TabVisibility(ShellTabVisibilityChanged(tabIndex: tab, isVisible: visible))
    }
}
