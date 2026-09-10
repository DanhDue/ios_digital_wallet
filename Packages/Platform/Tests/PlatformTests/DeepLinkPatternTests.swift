import Foundation
import XCTest
@testable import Platform

/// Boundary-value / equivalence-partition contract for ``DeepLinkPattern`` and
/// ``DeepLinkParams`` (Source Spec §4.2). `DeepLinkPattern` decides whether a
/// normalised ``DeepLink`` (Task 2) satisfies a declared pattern and, if so,
/// what parameters it yields; nothing consumes it yet — Task 4 wraps it in a
/// `DeepLinkRoute` and Task 5's router calls `match`.
///
/// Every test is named after the rule or boundary it pins, per the task
/// brief's six matching rules and its ten named Definition-of-Done scenarios.
final class DeepLinkPatternTests: XCTestCase {
    // MARK: - Test helpers

    /// Builds a `DeepLink` straight from a URL string, mirroring how a real
    /// caller would go from "string the OS handed me" to a normalised link.
    private func deepLink(_ urlString: String) -> DeepLink? {
        URL(string: urlString).flatMap(DeepLink.init(url:))
    }

    // MARK: - Literal match / parameter capture (DoD: "literal match", "parameter capture")

    func testAllLiteralPatternMatchesIdenticalPathWithNoParams() throws {
        let pattern = DeepLinkPattern("/settings")
        let link = try XCTUnwrap(deepLink("app://settings"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams([:]))
    }

    func testSingleParameterPatternCapturesPathSegmentAsParam() throws {
        let pattern = DeepLinkPattern("/tx/:id")
        let link = try XCTUnwrap(deepLink("app://tx/123"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": "123"]))
    }

    /// Covers both the "all-parameter" partition and the "adjacent
    /// parameters" partition: two `:` segments back-to-back, each capturing
    /// its own value with no literal separating them.
    func testPatternWithOnlyParametersCapturesEverySegmentIncludingAdjacentOnes() throws {
        let pattern = DeepLinkPattern("/:a/:b")
        let link = try XCTUnwrap(deepLink("app://foo/bar"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["a": "foo", "b": "bar"]))
    }

    // MARK: - Leading slash / root / empty pattern (DoD: "leading slash optional", "root pattern matches empty path")

    func testLeadingSlashIsOptionalAndStripped() {
        let withSlash = DeepLinkPattern("/settings")
        let withoutSlash = DeepLinkPattern("settings")

        XCTAssertEqual(withSlash, withoutSlash)
        XCTAssertEqual(withSlash.segments, [.literal("settings")])
    }

    func testRootPatternMatchesEmptyPath() throws {
        let pattern = DeepLinkPattern("/")
        let link = try XCTUnwrap(deepLink("app://"))

        XCTAssertEqual(pattern.segments, [])
        let params = try XCTUnwrap(pattern.match(link))
        XCTAssertEqual(params, DeepLinkParams([:]))
    }

    /// Adversarial: the empty pattern string carries the same "no segments"
    /// meaning as `"/"` — both must be indistinguishable to the matcher.
    func testEmptyStringPatternIsEquivalentToRootPattern() {
        let empty = DeepLinkPattern("")
        let root = DeepLinkPattern("/")

        XCTAssertEqual(empty, root)
        XCTAssertEqual(empty.segments, [])
    }

    /// Not explicitly named in the rule table, but symmetric with `DeepLink`'s
    /// own segment normalisation (empty subsequences are always dropped) —
    /// a trailing slash must not fabricate a phantom empty segment.
    func testTrailingSlashOnPatternIsStrippedLikeLeadingSlash() {
        let pattern = DeepLinkPattern("/settings/")

        XCTAssertEqual(pattern.segments, [.literal("settings")])
    }

    // MARK: - Segment-count boundaries (DoD: "segment count too few", "too many")

    func testPatternFailsToMatchWhenLinkHasTooFewSegments() throws {
        let pattern = DeepLinkPattern("/settings/language")
        let link = try XCTUnwrap(deepLink("app://settings"))

        XCTAssertNil(pattern.match(link))
    }

    func testPatternFailsToMatchWhenLinkHasTooManySegments() throws {
        let pattern = DeepLinkPattern("/settings")
        let link = try XCTUnwrap(deepLink("app://settings/language"))

        XCTAssertNil(pattern.match(link))
    }

    /// 0-segment pattern vs 1-segment link: the root pattern must not match
    /// any non-empty path.
    func testRootPatternFailsToMatchNonEmptyPath() throws {
        let pattern = DeepLinkPattern("/")
        let link = try XCTUnwrap(deepLink("app://settings"))

        XCTAssertNil(pattern.match(link))
    }

    /// 1-segment pattern vs 0-segment link: the inverse boundary of the
    /// above.
    func testSingleSegmentPatternFailsToMatchEmptyPath() throws {
        let pattern = DeepLinkPattern("/settings")
        let link = try XCTUnwrap(deepLink("app://"))

        XCTAssertNil(pattern.match(link))
    }

    /// Many-segment boundary: an exact, non-trivial segment count still
    /// matches when every segment lines up.
    func testManySegmentPatternMatchesEqualCountLinkExactly() throws {
        let pattern = DeepLinkPattern("/a/:b/c/:d/e")
        let link = try XCTUnwrap(deepLink("app://a/2/c/4/e"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["b": "2", "d": "4"]))
    }

    // MARK: - Case partitions (DoD: "case-insensitive literal", "parameter value case preserved")

    func testLiteralSegmentMatchIsCaseInsensitiveWhenPatternIsUppercase() throws {
        let pattern = DeepLinkPattern("/Settings/LANGUAGE")
        let link = try XCTUnwrap(deepLink("app://settings/language"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams([:]))
    }

    func testLiteralSegmentMatchIsCaseInsensitiveWhenLinkIsUppercase() throws {
        let pattern = DeepLinkPattern("/settings/language")
        let link = try XCTUnwrap(deepLink("app://SETTINGS/Language"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams([:]))
    }

    func testParameterValueCasePreservedExactlyEvenWhenMixedCase() throws {
        let pattern = DeepLinkPattern("/tx/:id")
        let link = try XCTUnwrap(deepLink("app://tx/AbC123"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": "AbC123"]), "parameter value must not be lowercased")
    }

    // MARK: - Path vs query merge (DoD: "path parameter beats a query parameter of the same name")

    func testPathParameterWinsOverQueryParameterWithSameName() throws {
        let pattern = DeepLinkPattern("/tx/:id")
        let link = try XCTUnwrap(deepLink("app://tx/p1?id=q1"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": "p1"]), "the path value must win over the colliding query value")
    }

    /// A query key with no matching path parameter is not swallowed — it
    /// must still be reachable through the merged params.
    func testQueryKeyWithNoMatchingPathParameterIsStillReachable() throws {
        let pattern = DeepLinkPattern("/settings")
        let link = try XCTUnwrap(deepLink("app://settings?locale=en"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["locale": "en"]))
    }

    /// Full-dictionary equality (not per-key subscript checks) proves both
    /// the colliding key and the non-colliding key are merged in the same
    /// result with no extras and no drops.
    func testPathParamsAndDistinctQueryParamsAreBothMergedInFull() throws {
        let pattern = DeepLinkPattern("/tx/:id")
        let link = try XCTUnwrap(deepLink("app://tx/p1?locale=en&id=ignored"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": "p1", "locale": "en"]))
    }

    // MARK: - Parameter naming edge cases

    /// Two `:id` segments in one pattern is not rejected here — grammar
    /// validation is ArchTests K10.3's job (a later task), not this
    /// permissive, non-validating `init`. Left-to-right assignment order
    /// means the later segment's value is what survives.
    func testDuplicateParameterNameInPatternKeepsTheLastSegmentsValue() throws {
        let pattern = DeepLinkPattern("/:id/:id")
        let link = try XCTUnwrap(deepLink("app://first/second"))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": "second"]))
    }

    /// Adversarial grammar edge: a pattern segment that is exactly `":"`
    /// still starts with `:`, so it is a parameter whose name is everything
    /// after the colon — the empty string. `init` is permissive by design
    /// (K10.3 rejects this shape at build time, not here), so this must not
    /// crash or trap; it must produce a well-defined, if odd, result.
    func testPatternSegmentThatIsExactlyColonYieldsEmptyStringParameterName() throws {
        let pattern = DeepLinkPattern(":")

        XCTAssertEqual(pattern.segments, [.parameter("")])

        let link = try XCTUnwrap(deepLink("app://anything"))
        let params = try XCTUnwrap(pattern.match(link))
        XCTAssertEqual(params, DeepLinkParams(["": "anything"]))
    }

    // MARK: - Adversarial opaque-segment handling

    /// Task 2 splits `percentEncodedPath` before decoding, so a scanned
    /// payload containing `/` (percent-encoded as `%2F`) arrives as a single
    /// opaque path element, never two. The matcher must bind that whole
    /// element to one parameter and must never re-split it.
    func testPercentEncodedSlashInLinkSegmentBindsAsOneOpaqueParameterValue() throws {
        let pattern = DeepLinkPattern("/scanner/result/:code")
        let link = try XCTUnwrap(deepLink("app://scanner/result/a%2Fb"))

        XCTAssertEqual(link.path, ["scanner", "result", "a/b"], "sanity: Task 2 keeps %2F inside the segment")

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["code": "a/b"]))
    }

    /// A valueless-looking but explicitly empty query value (`?a=`) must be
    /// preserved as `""`, not treated as if the key were absent. (A path
    /// segment can never itself be the empty string — `DeepLink` always
    /// removes empty path segments — so the only reachable empty-string
    /// parameter value comes from the query side.)
    func testEmptyQueryValueIsPreservedAsEmptyStringNotTreatedAsAbsent() throws {
        let pattern = DeepLinkPattern("/settings")
        let link = try XCTUnwrap(deepLink("app://settings?a="))

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["a": ""]))
        XCTAssertEqual(params["a"], "", "must be distinguishable from a missing key, not nil")
    }

    /// A captured value that syntactically looks like a pattern segment
    /// (starts with `:`) must be treated as opaque data, never reinterpreted.
    func testParameterValueThatSyntacticallyLooksLikeAPatternSegmentIsCapturedVerbatim() throws {
        let pattern = DeepLinkPattern("/tx/:id")
        let link = try XCTUnwrap(deepLink("app://tx/:not-a-param"))

        XCTAssertEqual(link.path, ["tx", ":not-a-param"], "sanity: the raw segment really does start with a colon")

        let params = try XCTUnwrap(pattern.match(link))

        XCTAssertEqual(params, DeepLinkParams(["id": ":not-a-param"]))
    }

    // MARK: - `nil` on failure is never a partially-populated result

    /// The first segment would bind `a` to a value before the second,
    /// mismatching literal is reached. The overall result must still be a
    /// clean `nil`, never an `Optional` wrapping a params object that only
    /// picked up the first parameter.
    func testFailedMatchAfterPartialParameterCaptureReturnsNilNotPartialParams() throws {
        let pattern = DeepLinkPattern("/:a/beta")
        let link = try XCTUnwrap(deepLink("app://alpha/gamma"))

        let result = pattern.match(link)

        XCTAssertNil(result, "a mismatch anywhere in the pattern must discard any parameters captured so far")
    }
}
