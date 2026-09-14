import Combine
import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

#if canImport(UIKit)
    import UIKit
#endif

/// A route with **no entry in `AppRoutes`** — the shape of every feature-private
/// child screen a future deep link will target. Declared here (App test
/// target), not in a Feature module: only this file registers it.
private struct UnregisteredRoute: AppRoute {
    let id: Int
}

/// Handles only `UnregisteredRoute`, so a nonzero call count proves resolution
/// came from `ShellView`'s single erased `.navigationDestination`, not from
/// the Settings/Scanner providers `AppComposition` already registers.
private final class UnregisteredRouteProvider: RouteProvider {
    private(set) var destinationCallCount = 0

    func canHandle(_ route: any AppRoute) -> Bool {
        route is UnregisteredRoute
    }

    func destination(for _: any AppRoute) -> AnyView {
        destinationCallCount += 1
        return AnyView(Text("unregistered"))
    }
}

/// Tier C — the §4.3 end-to-end navigation flow, driven through the *composed*
/// app (router + providers + shell built by `AppComposition`).
@MainActor
final class NavigationFlowTests: XCTestCase {
    // MARK: Selecting the Settings tab

    func testSelectingSettingsTabPublishesVisibilityAndResolvesTheSettingsProvider() throws {
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus)
        let recorder = Recorder(bus.on(ShellTabVisibilityChanged.self).map { TabVisibility($0) })

        // Cold start selects settings tab with no event; move away then back so the
        // show/hide pair for the settings tab is observable.
        let settingsTab = sut.shellViewModel.config.tabCount - 1
        sut.shellViewModel.dispatch(.selectTab(0))
        sut.shellViewModel.dispatch(.selectTab(settingsTab))

        XCTAssertEqual(sut.router.selectedTab, settingsTab)
        XCTAssertEqual(recorder.values.last, TabVisibility.make(tab: settingsTab, visible: true))

        // AppRouter.destination(for: SettingsRoot()) resolves the SettingsFeature provider.
        let settingsProviders = sut.routeProviders.filter { $0.canHandle(AppRoutes.SettingsRoot()) }
        XCTAssertEqual(settingsProviders.count, 1)
        let resolved = try XCTUnwrap(settingsProviders.first)
        XCTAssertTrue(String(describing: type(of: resolved)).contains("SettingsRouteProvider"))
    }

    // MARK: Per-tab stack preservation

    func testDeepPushThenTabSwitchThenBackPreservesThePerTabStack() {
        let sut = AppComposition(eventBus: AppEventBus())
        let settingsTab = sut.shellViewModel.config.tabCount - 1

        sut.router.navigate(to: AppRoutes.SettingsRoot(), inTab: settingsTab)
        XCTAssertEqual(sut.router.tabPaths[settingsTab].count, 1)

        sut.router.switchTab(0)
        sut.router.switchTab(settingsTab)

        XCTAssertEqual(sut.router.tabPaths[settingsTab].count, 1, "settings tab still shows the pushed screen")
        XCTAssertEqual(sut.router.tabPaths[0].count, 0, "tab 0 keeps its own (empty) stack")
        XCTAssertEqual(sut.router.selectedTab, settingsTab)
    }

    // MARK: Hosting the composed shell

    #if canImport(UIKit)
        func testHostingTheComposedShellRendersAndDefaultsToSettings() {
            let sut = AppComposition(eventBus: AppEventBus())
            let expectedTab = sut.shellViewModel.config.initialTab
            let expectedCount = sut.shellViewModel.config.tabCount

            let host = UIHostingController(rootView: RootView(composition: sut))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            XCTAssertNotNil(host.view)
            XCTAssertEqual(sut.router.selectedTab, expectedTab, "Settings is the default-selected tab")
            XCTAssertEqual(sut.router.tabPaths.count, expectedCount, "number of configured tabs")
        }
    #endif

    // MARK: Blank-screen closure (blocker D3)

    #if canImport(UIKit)
        func testPushingARouteWithNoAppRoutesEntryResolvesThroughTheErasedDestinationInsteadOfBlank() {
            // Before the AnyAppRoute erasure, ShellView named only
            // AppRoutes.SettingsRoot / .ScannerRoot in its .navigationDestinations,
            // so any other route — every feature-private child screen a deep link
            // would need to reach — rendered nothing. This is the "demonstrated
            // by a test, not by inspection" proof the task's Definition of Done
            // requires, exercised through the fully composed app on a live host.
            let sut = AppComposition(eventBus: AppEventBus())
            let provider = UnregisteredRouteProvider()
            sut.router.register(provider)
            sut.router.navigate(to: UnregisteredRoute(id: 1), inTab: sut.router.selectedTab)

            let host = UIHostingController(rootView: RootView(composition: sut))
            // A `NavigationStack` only walks an already-populated path into its
            // `.navigationDestination` closures once it is part of a real key
            // window — `loadViewIfNeeded()` alone (as the sibling test above
            // uses for a *rootless* check) is not enough here.
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            XCTAssertNotNil(host.view)
            XCTAssertGreaterThan(
                provider.destinationCallCount,
                0,
                "a route absent from AppRoutes must resolve through the single erased destination, not render blank"
            )
        }
    #endif
}

extension TabVisibility {
    static func make(tab: Int, visible: Bool) -> TabVisibility {
        TabVisibility(ShellTabVisibilityChanged(tabIndex: tab, isVisible: visible))
    }
}
