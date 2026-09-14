import Combine
import Core
import Platform
import Scanner
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Enterprise mode tests verifying Scanner composition and routing.
/// Extracted from AppCompositionTests so the test suite is mode-aware.
@MainActor
final class ScannerCompositionTests: XCTestCase {
    func testCompositionRegistersAProviderForScannerRoot() {
        let sut = AppComposition(eventBus: AppEventBus())
        let handlesScanner = sut.routeProviders.filter { $0.canHandle(AppRoutes.ScannerRoot()) }
        XCTAssertEqual(handlesScanner.count, 1, "exactly one provider handles ScannerRoot in enterprise mode")
    }

    func testRouterResolvesScannerRoot() {
        let sut = AppComposition(eventBus: AppEventBus())
        _ = sut.router.destination(for: AppRoutes.ScannerRoot())
    }

    func testRouterIsBuiltWithThreeTabsInEnterpriseMode() {
        let sut = AppComposition(eventBus: AppEventBus())
        XCTAssertEqual(sut.router.tabPaths.count, 3)
        XCTAssertEqual(sut.router.selectedTab, 2)
    }

    func testDeepLinkRouterResolvesScannerPatterns() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner")), .opened)
        XCTAssertEqual(sut.router.selectedTab, 1, "Scanner's /scanner lands on tab 1")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "ScannerRoot is tab 1's own root — no duplicate push")

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123")), .opened)
        XCTAssertEqual(sut.router.selectedTab, 1)
        XCTAssertEqual(
            sut.router.tabPaths[1].count, 1,
            "ScannerRoot dropped as tab 1's own root; only ScannerResultRoute pushed"
        )
    }

    func testPublishingUserLoggedInDrainsAPendingRedirectedLinkToScanner() {
        var allow = false
        let fakeGuard = FakeDeepLinkGuard { stack, requiresAuth in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow
            }
            guard requiresAuth else { return .allow }
            return allow ? .allow : .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
        }
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus, deepLinkGuard: fakeGuard)
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/gated", requiresAuth: true) { _ in [AppRoutes.ScannerRoot()] },
        ]))

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://gated")), .pendingGuard)
        XCTAssertEqual(sut.router.selectedTab, 2, "redirected to SettingsRoot (tab 2) while pending")

        allow = true
        bus.publish(UserLoggedIn())
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(sut.router.selectedTab, 1, "drainPending replayed the original stack onto Scanner (tab 1)")
    }

    func testPublishingAnUnrelatedEventDoesNotDrainAPendingScannerLink() {
        let fakeGuard = FakeDeepLinkGuard { stack, requiresAuth in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow
            }
            guard requiresAuth else { return .allow }
            return .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
        }
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus, deepLinkGuard: fakeGuard)
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/gated", requiresAuth: true) { _ in [AppRoutes.ScannerRoot()] },
        ]))

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://gated")), .pendingGuard)
        XCTAssertEqual(sut.router.selectedTab, 2)

        bus.publish(AppLifecycleChanged(state: .background))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(sut.router.selectedTab, 2, "an unrelated event must never drain the pending link")
    }

    func testTwoURLsOpenedInImmediateSuccessionWithScannerWinning() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://settings")), .opened)
        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner")), .opened)

        XCTAssertEqual(sut.router.selectedTab, 1, "the second call's tab must win cleanly")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "ScannerRoot, its own tab root — no leftover state")
    }
}
