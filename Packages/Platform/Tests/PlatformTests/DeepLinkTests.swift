import Foundation
import XCTest
@testable import Platform

/// Boundary-value / equivalence-partition contract for ``DeepLink``, the
/// value type that turns a raw `URL` into the normalised `path` segments and
/// `query` dictionary the router (Task 5) will match patterns (Task 3)
/// against (Source Spec §4.1).
///
/// The single invariant every later task depends on: for a *custom* scheme
/// the host carries the first meaningful segment, while for an `http`/`https`
/// Universal Link the host is domain noise and is discarded — collapsing
/// both surfaces into one `path` array lets patterns be written once. Every
/// test below is named after the normalisation rule it pins, per the task
/// brief's rule table.
final class DeepLinkTests: XCTestCase {
    // MARK: - Test helper

    /// Builds a `DeepLink` straight from a URL string, mirroring how a real
    /// caller would go from "string the OS handed me" to "normalised link".
    /// Returns `nil` if either `URL(string:)` or `DeepLink.init?` fails.
    private func deepLink(_ urlString: String) -> DeepLink? {
        URL(string: urlString).flatMap(DeepLink.init(url:))
    }

    // MARK: - Happy paths / host-path asymmetry

    func testCustomSchemePrependsHostAsFirstSegment() throws {
        let link = try XCTUnwrap(deepLink("app://settings/language"))

        XCTAssertEqual(link.path, ["settings", "language"])
        XCTAssertEqual(link.query, [:])
    }

    func testHTTPSUniversalLinkDiscardsTheHost() throws {
        let link = try XCTUnwrap(deepLink("https://example.com/settings/language"))

        XCTAssertEqual(link.path, ["settings", "language"])
    }

    func testHTTPUniversalLinkAlsoDiscardsTheHost() throws {
        let link = try XCTUnwrap(deepLink("http://example.com/settings/language"))

        XCTAssertEqual(link.path, ["settings", "language"])
    }

    // MARK: - Segment-count boundaries

    func testEmptyPathIsLegalForBareCustomSchemeHost() throws {
        let link = try XCTUnwrap(deepLink("app://"))

        XCTAssertEqual(link.path, [])
        XCTAssertEqual(link.query, [:])
    }

    func testSingleSegmentPathWhenHostCarriesTheOnlySegment() throws {
        let link = try XCTUnwrap(deepLink("app://settings"))

        XCTAssertEqual(link.path, ["settings"])
    }

    func testManySegmentPath() throws {
        let link = try XCTUnwrap(deepLink("app://a/b/c/d"))

        XCTAssertEqual(link.path, ["a", "b", "c", "d"])
    }

    func testVeryLongPathPreservesEveryGeneratedSegmentInOrder() throws {
        let expectedSegments = (0 ..< 50).map { "s\($0)" }
        let urlString = "app://" + expectedSegments.joined(separator: "/")

        let link = try XCTUnwrap(deepLink(urlString))

        XCTAssertEqual(link.path, expectedSegments)
        XCTAssertEqual(link.path.count, 50)
    }

    // MARK: - Slash normalisation

    func testTrailingSlashProducesNoEmptySegment() throws {
        let link = try XCTUnwrap(deepLink("app://settings/language/"))

        XCTAssertEqual(link.path, ["settings", "language"])
    }

    func testDoubledSlashCollapsesWithNoEmptySegment() throws {
        let link = try XCTUnwrap(deepLink("app://settings//language"))

        XCTAssertEqual(link.path, ["settings", "language"])
    }

    func testURLWithOnlySlashesNormalisesToAnEmptyPath() throws {
        let link = try XCTUnwrap(deepLink("app:///"))

        XCTAssertEqual(link.path, [])
    }

    func testSchemeOnlyURLNormalisesToAnEmptyPathAndQuery() throws {
        let link = try XCTUnwrap(deepLink("app:"))

        XCTAssertEqual(link.path, [])
        XCTAssertEqual(link.query, [:])
    }

    // MARK: - Query partitions

    func testAbsentQueryYieldsAnEmptyDictionary() throws {
        let link = try XCTUnwrap(deepLink("app://settings"))

        XCTAssertEqual(link.query, [:])
    }

    func testEmptyQueryMarkerYieldsAnEmptyDictionary() throws {
        let link = try XCTUnwrap(deepLink("app://settings?"))

        XCTAssertEqual(link.query, [:])
    }

    func testSingleQueryParameter() throws {
        let link = try XCTUnwrap(deepLink("app://settings?locale=en"))

        XCTAssertEqual(link.query, ["locale": "en"])
    }

    func testMultipleDistinctQueryParameters() throws {
        let link = try XCTUnwrap(deepLink("app://settings?a=1&b=2"))

        XCTAssertEqual(link.query, ["a": "1", "b": "2"])
    }

    func testDuplicateQueryKeyLastOneWins() throws {
        let link = try XCTUnwrap(deepLink("app://settings?a=1&a=2"))

        XCTAssertEqual(link.query, ["a": "2"])
    }

    func testValuelessQueryItemMapsToEmptyString() throws {
        let link = try XCTUnwrap(deepLink("app://settings?flag"))

        XCTAssertEqual(link.query, ["flag": ""])
    }

    func testQueryKeyWithExplicitEmptyValue() throws {
        let link = try XCTUnwrap(deepLink("app://settings?a="))

        XCTAssertEqual(link.query, ["a": ""])
    }

    func testPercentEncodedQueryValueArrivesDecoded() throws {
        let link = try XCTUnwrap(deepLink("app://settings?a=hello%20world"))

        XCTAssertEqual(link.query, ["a": "hello world"])
    }

    // MARK: - Percent-encoding / unicode in the path

    func testPercentEncodedPathSegmentArrivesDecoded() throws {
        let link = try XCTUnwrap(deepLink("app://settings/%C3%A9"))

        XCTAssertEqual(link.path, ["settings", "é"])
    }

    func testRawUnicodePathSegmentIsPreserved() throws {
        let link = try XCTUnwrap(deepLink("app://settings/héllo"))

        XCTAssertEqual(link.path, ["settings", "héllo"])
    }

    /// Per RFC 3986 §3.3, a percent-encoded slash (`%2F`) is data *within* a
    /// segment, not a delimiter. `normalisedSegments(for:)` splits
    /// `percentEncodedPath` on `/` before decoding each segment, so `%2F`
    /// never gets mistaken for a literal path separator: `"lang%2Fuage"`
    /// decodes to the single segment `"lang/uage"`, never two segments.
    func testPercentEncodedSlashStaysInsideItsSegment() throws {
        let link = try XCTUnwrap(deepLink("app://settings/lang%2Fuage"))

        XCTAssertEqual(link.path, ["settings", "lang/uage"])
    }

    /// Pins the regression that motivated the `%2F`-stays-in-segment rule:
    /// Task 7 declares the pattern `/scanner/result/:code` for a scanned QR
    /// payload. A scanned code containing `/` arrives percent-encoded. If a
    /// `%2F` were ever treated as a segment boundary again, this URL would
    /// normalise to four segments instead of three, the three-segment
    /// pattern would fail to match, and the deep link would silently do
    /// nothing — a failure invisible from the app's behaviour.
    func testScannerResultDeepLinkWithEncodedSlashInPayloadStaysThreeSegments() throws {
        let link = try XCTUnwrap(deepLink("app://scanner/result/a%2Fb"))

        XCTAssertEqual(link.path, ["scanner", "result", "a/b"])
    }

    // MARK: - Case partitions

    func testCustomSchemeHostAndPathSegmentsAreStoredVerbatimNeverLowercased() throws {
        let link = try XCTUnwrap(deepLink("app://SETTINGS/Language"))

        XCTAssertEqual(link.path, ["SETTINGS", "Language"])
    }

    func testSchemeComparisonForTheHostRuleIsCaseInsensitive() throws {
        let link = try XCTUnwrap(deepLink("HTTPS://Example.com/Settings/Language"))

        XCTAssertEqual(link.path, ["Settings", "Language"], "HTTPS:// must still be treated as a web scheme")
    }

    // MARK: - Malformed / hostile input

    func testEmptyStringFailsAtURLConstructionSoNoDeepLinkResults() {
        XCTAssertNil(URL(string: ""), "sanity: this string never becomes a URL in the first place")
        XCTAssertNil(deepLink(""))
    }

    func testUnterminatedIPv6HostBracketFailsAtURLConstructionSoNoDeepLinkResults() {
        XCTAssertNil(URL(string: "app://[bad_host/path"), "sanity: malformed IPv6 host bracket never becomes a URL")
        XCTAssertNil(deepLink("app://[bad_host/path"))
    }

    // MARK: - Equatable contract

    func testTwoDeepLinksFromTheIdenticalURLStringAreEqual() throws {
        let lhs = try XCTUnwrap(deepLink("app://settings/language"))
        let rhs = try XCTUnwrap(deepLink("app://settings/language"))

        XCTAssertEqual(lhs, rhs)
    }

    func testTwoDeepLinksFromDifferentURLStringsAreNotEqualEvenWithMatchingNormalisedPath() throws {
        let lhs = try XCTUnwrap(deepLink("app://settings/language"))
        let rhs = try XCTUnwrap(deepLink("app://settings/language/"))

        XCTAssertEqual(lhs.path, rhs.path, "both normalise to the same segments")
        XCTAssertNotEqual(lhs, rhs, "equality is field-wise over `url` too, not just the normalised projection")
    }

    // MARK: - Sendable contract

    func testDeepLinkCrossesAnIsolationBoundaryUnchanged() async throws {
        let link = try XCTUnwrap(deepLink("app://settings/language?locale=en"))

        let roundTripped: DeepLink = await Task.detached { @Sendable in
            link
        }.value

        XCTAssertEqual(roundTripped, link)
        XCTAssertEqual(roundTripped.path, ["settings", "language"])
        XCTAssertEqual(roundTripped.query, ["locale": "en"])
    }
}
