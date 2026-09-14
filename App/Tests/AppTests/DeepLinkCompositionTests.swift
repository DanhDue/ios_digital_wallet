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
    private struct FirstRoute: AppRoute {}
    private struct SecondRoute: AppRoute {}

    private struct TestResolver: TabResolver {
        func placement(for route: any AppRoute) -> Platform.TabPlacement? {
            switch route {
            case is FirstRoute: Platform.TabPlacement(tab: 0, isTabRoot: true)
            case is SecondRoute: Platform.TabPlacement(tab: 1, isTabRoot: true)
            default: nil
            }
        }
    }

    // MARK: Registration order (first match wins)

    func testProvidersAreRegisteredInTheOrderTheyAppearInTheProvidersArray() {
        let router = AppRouter(tabCount: 2, initialTab: 1)
        let first = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [FirstRoute()] },
        ])
        let second = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [SecondRoute()] },
        ])
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [first, second],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: TestResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://dup")), .opened)
        XCTAssertEqual(router.selectedTab, 0, "the FIRST-registered provider's /dup must win")
    }

    func testReversingProviderOrderReversesWhichPatternWins() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let first = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [FirstRoute()] },
        ])
        let second = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/dup") { _ in [SecondRoute()] },
        ])
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [second, first],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: TestResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://dup")), .opened)
        XCTAssertEqual(router.selectedTab, 1, "now SECOND-registered provider's /dup must win")
    }

    // MARK: Existential-typed registration (carried note, Task 4's review)

    func testRegistrationDrivenThroughAnExistentialRouteProviderBindingStillReadsTheOverriddenDeepLinks() {
        // `deepLinks` is a `@MainActor` protocol requirement with a default
        // `[]` implementation in an extension. Binding the concrete provider
        // to an explicit `any RouteProvider` local — not just relying on
        // array-literal boxing — proves dynamic dispatch reaches the
        // *overridden* `deepLinks`, not the protocol's default.
        let provider: any RouteProvider = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/existential-check") { _ in [SecondRoute()] },
        ])
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let deepLinkRouter = DeepLinkComposition.makeRouter(
            router: router,
            providers: [provider],
            deepLinkGuard: FakeDeepLinkGuard(),
            tabResolver: TestResolver()
        )

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://existential-check")), .opened)
        XCTAssertEqual(router.selectedTab, 1)
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
