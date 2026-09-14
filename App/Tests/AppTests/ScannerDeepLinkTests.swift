import Platform
import Scanner
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Scanner-specific deep link and tab placement tests.
/// Extracted so deep link tests are mode-aware.
@MainActor
final class ScannerDeepLinkTests: XCTestCase {
    func testScannerRootResolvesToTabOneAsItsOwnRoot() {
        let sut = ShellTabResolver()

        XCTAssertEqual(
            sut.placement(for: AppRoutes.ScannerRoot()),
            Platform.TabPlacement(tab: 1, isTabRoot: true)
        )
    }

    func testScannerResultRouteHasNoOpinion() {
        let sut = ShellTabResolver()
        let scannerResultRoute = ScannerResultRoute(code: "ABC123")

        XCTAssertNil(
            sut.placement(for: scannerResultRoute),
            "feature-private child route has no tab placement opinion"
        )
    }

    func testProvidersAreRegisteredInTheOrderTheyAppearInTheProvidersArray() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        let first = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [AppRoutes.ScannerRoot()] },
        ])
        let second = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [AppRoutes.SettingsRoot()] },
        ])
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [first, second],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: ShellTabResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://dup")), .opened)
        XCTAssertEqual(router.selectedTab, 1, "the FIRST-registered provider's /dup must win")
    }

    func testReversingProviderOrderReversesWhichPatternWins() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        let first = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [AppRoutes.ScannerRoot()] },
        ])
        let second = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [AppRoutes.SettingsRoot()] },
        ])
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [second, first],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: ShellTabResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://dup")), .opened)
        XCTAssertEqual(router.selectedTab, 2, "now SECOND-registered (settings) provider's /dup must win")
    }
}
