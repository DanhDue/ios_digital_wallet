import Platform
import XCTest
@testable import iOSDigitalWallet

/// Tier A — `DeepLinkComposition.makeRouter` (Task 8): builds the
/// `DeepLinkRouter` over an `AppRouter`, installs the guard + resolver, and
/// registers every `RouteProvider` in order. Exercised directly (not through
/// the full `AppComposition`) so registration-order and existential-binding
/// behavior can be pinned without depending on the shipped features' exact
/// URL contracts.
@MainActor
final class DeepLinkCompositionTests: XCTestCase {
    // MARK: Registration order (first match wins)

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

    // MARK: Existential-typed registration (carried note, Task 4's review)

    func testRegistrationDrivenThroughAnExistentialRouteProviderBindingStillReadsTheOverriddenDeepLinks() {
        // `deepLinks` is a `@MainActor` protocol requirement with a default
        // `[]` implementation in an extension. Binding the concrete provider
        // to an explicit `any RouteProvider` local — not just relying on
        // array-literal boxing — proves dynamic dispatch reaches the
        // *overridden* `deepLinks`, not the protocol's default.
        let provider: any RouteProvider = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/existential-check") { _ in [AppRoutes.SettingsRoot()] },
        ])
        let router = AppRouter(tabCount: 3, initialTab: 0)
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [provider],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: ShellTabResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://existential-check")), .opened)
        XCTAssertEqual(router.selectedTab, 2)
    }

    // MARK: A provider declaring no deepLinks contributes zero entries

    func testAProviderThatDeclaresNoDeepLinksContributesNothingToTheTable() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let silent = FakeDeepLinkRouteProvider([])
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [silent],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: ShellTabResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://anything")), .unmatched)
    }
}
