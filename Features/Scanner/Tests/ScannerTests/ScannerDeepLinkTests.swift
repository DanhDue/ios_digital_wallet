import Platform
import XCTest
@testable import Scanner

/// Boundary-value / equivalence-partition contract for
/// `ScannerRouteProvider.deepLinks` (Task 7, Source Spec §4.11) — the
/// Scanner feature's own URL contract. Every test here builds a `DeepLink`
/// from a real `URL`, runs it through the *declared* pattern's `match`, and
/// feeds the resulting `DeepLinkParams` to `build`, asserting the exact
/// produced stack. Nothing here goes through `DeepLinkRouter` (Task 5) or
/// any app target — `swift test --package-path Features/Scanner` exercises
/// this end to end with no Tuist project generated, proving invariant R2:
/// a feature owns its deep links and can test them standalone.
@MainActor
final class ScannerDeepLinkTests: XCTestCase {
    private func makeProvider() -> ScannerRouteProvider {
        ScannerRouteProvider { ScannerViewModel(repository: SpyScannerRepository()) }
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
    /// concrete route *types* and their payloads in exact declared order —
    /// mirrors the `AnyAppRoute` equality convention already used by
    /// `ScannerRouteProviderTests`.
    private func erased(_ routes: [any AppRoute]) -> [AnyAppRoute] {
        routes.map(AnyAppRoute.init)
    }

    // MARK: - /scanner

    func testScannerPatternMatchesAndBuildsTheTabRoot() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://scanner"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))
        let built = matched.route.build(matched.params)

        XCTAssertEqual(erased(built), erased([AppRoutes.ScannerRoot()]))
        XCTAssertFalse(matched.route.requiresAuth, "no shipped route sets requiresAuth: true")
    }

    func testScannerLiteralIsCaseInsensitiveUppercaseSchemeHostStillMatches() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://SCANNER"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))
        let built = matched.route.build(matched.params)

        XCTAssertEqual(erased(built), erased([AppRoutes.ScannerRoot()]))
    }

    // MARK: - /scanner/result/:code

    func testScannerResultPatternMatchesAndBuildsTwoElementStackInOrder() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://scanner/result/ABC123"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))
        XCTAssertEqual(matched.params["code"], "ABC123")

        let built = matched.route.build(matched.params)

        XCTAssertEqual(
            erased(built),
            erased([AppRoutes.ScannerRoot(), ScannerResultRoute(code: "ABC123")]),
            "must build the parent chain [ScannerRoot, ScannerResultRoute] in that exact order"
        )
        XCTAssertFalse(matched.route.requiresAuth)
    }

    func testScannerResultMixedCaseLiteralsStillMatchAndCapturedCodeKeepsItsOriginalCase() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://Scanner/Result/AbC123"))

        let matched = try XCTUnwrap(firstMatch(in: provider.deepLinks, for: link))

        XCTAssertEqual(matched.params["code"], "AbC123", "literals compare case-insensitively; the capture never does")

        let built = matched.route.build(matched.params)
        XCTAssertEqual(erased(built), erased([AppRoutes.ScannerRoot(), ScannerResultRoute(code: "AbC123")]))
    }

    func testScannerResultMissingCodeSegmentDoesNotMatchAnyDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://scanner/result"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link), "one segment short of :code must not match")
    }

    func testScannerResultExtraSegmentDoesNotMatchAnyDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://scanner/result/ABC123/extra"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link), "one segment beyond :code must not match")
    }

    func testUnrelatedSettingsPathDoesNotMatchAnyScannerDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://settings/unknown"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link))
    }

    func testDifferentFeaturePathDoesNotMatchAnyScannerDeclaredPattern() throws {
        let provider = makeProvider()
        let link = try XCTUnwrap(deepLink("app://wallet/send"))

        XCTAssertNil(firstMatch(in: provider.deepLinks, for: link))
    }

    // MARK: - :code payload partitions (Equivalence Partitioning)

    /// `(percent-encoded URL path segment, expected decoded code)`. Mirrors
    /// `ScannerRouteProviderTests.codePartitions`: short, long, unicode, a
    /// code containing `/` (Task 2's `%2F`-stays-one-segment rule), and a
    /// code that looks like a URL.
    private static let codePartitions: [(encoded: String, decoded: String)] = [
        ("A", "A"),
        (String(repeating: "x", count: 2000), String(repeating: "x", count: 2000)),
        ("%E9%98%BF%CE%B2%F0%9F%8E%89", "阿β🎉"),
        ("abc%2Fdef%2Fghi", "abc/def/ghi"),
        ("https%3A%2F%2Fexample.com%2Fproduct%3Fid%3D42", "https://example.com/product?id=42"),
    ]

    func testScannerResultCapturedCodeReachesTheBuiltRouteUnmodifiedAcrossEveryPayloadPartition() throws {
        let provider = makeProvider()

        for partition in Self.codePartitions {
            let link = try XCTUnwrap(
                deepLink("app://scanner/result/\(partition.encoded)"),
                "test setup for partition \(partition.decoded.prefix(24))"
            )
            let matched = try XCTUnwrap(
                firstMatch(in: provider.deepLinks, for: link),
                "partition \(partition.decoded.prefix(24)) must match /scanner/result/:code"
            )

            XCTAssertEqual(matched.params["code"], partition.decoded)

            let built = matched.route.build(matched.params)
            XCTAssertEqual(
                erased(built),
                erased([AppRoutes.ScannerRoot(), ScannerResultRoute(code: partition.decoded)]),
                "partition \(partition.decoded.prefix(24)) must reach the built route unmodified"
            )
        }
    }

    // MARK: - Declaration shape

    func testDeclaresExactlyTwoRoutesInStableOrder() {
        let provider = makeProvider()

        let patterns = provider.deepLinks.map(\.pattern)
        XCTAssertEqual(patterns, [DeepLinkPattern("/scanner"), DeepLinkPattern("/scanner/result/:code")])

        // Reading the computed property twice must yield the same order every time.
        XCTAssertEqual(patterns, provider.deepLinks.map(\.pattern))
    }

    func testNoDeclaredScannerRouteRequiresAuth() {
        let provider = makeProvider()

        XCTAssertTrue(provider.deepLinks.allSatisfy { !$0.requiresAuth })
    }
}
