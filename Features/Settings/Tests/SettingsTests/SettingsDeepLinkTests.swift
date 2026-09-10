import Platform
import XCTest
@testable import Settings

/// Boundary-value / equivalence-partition contract for
/// `SettingsRouteProvider.deepLinks` (Task 7, Source Spec §4.11) — the
/// Settings feature's own URL contract. Every test here builds a `DeepLink`
/// from a real `URL`, runs it through the *declared* pattern's `match`, and
/// feeds the resulting `DeepLinkParams` to `build`, asserting the exact
/// produced stack. Nothing here goes through `DeepLinkRouter` (Task 5) or
/// any app target — `swift test --package-path Features/Settings` exercises
/// this end to end with no Tuist project generated, proving invariant R2:
/// a feature owns its deep links and can test them standalone.
@MainActor
final class SettingsDeepLinkTests: XCTestCase {
    private func makeProvider() -> SettingsRouteProvider {
        SettingsRouteProvider { SettingsViewModel(repository: SpySettingsRepository()) }
    }

    /// Builds a `DeepLink` from `urlString`, failing the test (never
    /// crashing) if either `URL(string:)` or `DeepLink.init?` returns `nil`.
    private func deepLink(_ urlString: String, file: StaticString = #filePath, line: UInt = #line) -> DeepLink? {
        guard let url = URL(string: urlString) else {
            XCTFail("test setup: '\(urlString)' must construct a URL", file: file, line: line)
            return nil
        }
        return DeepLink(url: url)
    }

    /// Walks the provider's declared routes exactly the way the router
    /// engine resolves first-match-wins (Task 5), without depending on
    /// `DeepLinkRouter` itself — this package must build with no other
    /// feature or the router in scope.
    private func firstMatch(
        in routes: [DeepLinkRoute],
        for link: DeepLink
    ) -> (route: DeepLinkRoute, params: DeepLinkParams)? {
        for route in routes {
            if let params = route.pattern.match(link) {
                return (route, params)
            }
        }
        return nil
    }

    /// Type-erases a built stack so `XCTAssertEqual` can compare both the
    /// concrete route *types* and their payloads in exact declared order.
    private func erased(_ routes: [any AppRoute]) -> [AnyAppRoute] {
        routes.map(AnyAppRoute.init)
    }

    // MARK: - /settings

    func testSettingsPatternMatchesAndBuildsTheTabRoot() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://settings"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))
        let built = matched.route.build(matched.params)

        XCTAssertEqual(erased(built), erased([AppRoutes.SettingsRoot()]))
        XCTAssertFalse(matched.route.requiresAuth, "no shipped route sets requiresAuth: true")
    }

    func testSettingsLiteralIsCaseInsensitiveUppercaseSchemeHostStillMatches() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://SETTINGS"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))
        let built = matched.route.build(matched.params)

        XCTAssertEqual(erased(built), erased([AppRoutes.SettingsRoot()]))
    }

    func testSettingsUnknownSiblingPathDoesNotMatchAnyDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://settings/unknown"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link), "an undeclared child of /settings must not match")
    }

    func testDifferentFeaturePathDoesNotMatchAnyDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://scanner"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link), "Scanner's own path must not match Settings")
    }

    // MARK: - Declaration shape

    func testDeclaresExactlyOneRoute() {
        let provider = makeProvider()

        XCTAssertEqual(provider.deepLinks.count, 1)
        XCTAssertEqual(provider.deepLinks.map(\.pattern), [DeepLinkPattern("/settings")])
    }

    func testNoDeclaredSettingsRouteRequiresAuth() {
        let provider = makeProvider()

        XCTAssertTrue(provider.deepLinks.allSatisfy { !$0.requiresAuth })
    }
}
