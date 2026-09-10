import Foundation

/// A declared route shape, matched against a normalised ``DeepLink`` (Task
/// 2) to decide whether it applies and, if so, what parameters it captures
/// (Source Spec §4.2).
///
/// **Matching rules:**
///
/// | Rule | Behaviour |
/// |---|---|
/// | Leading `/` | optional; stripped |
/// | Segment starting with `:` | a parameter; the rest of the segment is its name |
/// | Any other segment | a literal |
/// | Segment count | must match the link's path **exactly** — no wildcards, no globbing, no optional segments |
/// | Literal comparison | case-insensitive (both sides lowercased) |
/// | Parameter values | keep their original case, verbatim from `link.path` |
/// | Path parameters vs. query items | path parameters win on a name collision |
/// | `"/"` | zero segments; matches a link whose `path` is empty |
///
/// **Why exact segment count, no wildcards.** A prefix or wildcard match
/// would make resolution order significant and would make ArchTests
/// K10.1's "no duplicate patterns" check meaningless — two distinct pattern
/// strings could still overlap for real URLs. Exact matching keeps "unique
/// pattern" and "unambiguous resolution" the same property. Add richer
/// matching only when a real link needs it (YAGNI).
///
/// **`init` is intentionally permissive, not validating.** It never rejects
/// a malformed pattern string at runtime — `DeepLinkPattern(":")` is legal
/// and produces a parameter named `""`. Pattern grammar (literal
/// `^[a-z0-9-]+$`, parameter `^:[a-z][a-zA-Z0-9]*$`) is enforced once, at
/// build time, by ArchTests K10.3 (a later task), which walks `segments` —
/// the same parsing this type already does for every pattern — rather than
/// re-deriving the split/classify logic itself.
///
/// **`Hashable`** — K10.1 forbids duplicate patterns and the router's
/// dispatch table (Task 5) is keyed on this type, both of which want a
/// hashable value.
///
/// **`Sendable`** — every stored property is a value type.
public struct DeepLinkPattern: Hashable, Sendable {
    /// One element of a parsed pattern: either fixed text to compare
    /// case-insensitively, or a named capture that binds to whatever
    /// occupies that position in a matched link's path.
    public enum Segment: Hashable, Sendable {
        /// Fixed text. Compared to the link's segment case-insensitively;
        /// the case the pattern was authored in carries no meaning.
        case literal(String)

        /// A capture. The associated string is the parameter's name (the
        /// text after `:`, which may be empty for a malformed `":"`
        /// segment — see the permissive-`init` note above).
        case parameter(String)
    }

    /// The pattern, parsed into an ordered list of literal and parameter
    /// segments. This is the single place pattern strings are ever split —
    /// `match(_:)` only ever walks this array, it never re-parses the
    /// original string, so there is exactly one definition of "how a
    /// pattern breaks into segments" for K10.3 to reuse.
    public let segments: [Segment]

    /// Parses `pattern` into `segments`. A leading `/` is optional and
    /// stripped; consecutive or trailing `/` never produce an empty segment
    /// (mirroring `DeepLink`'s own path normalisation); `"/"` and `""` both
    /// parse to zero segments. Never fails and never validates — see the
    /// permissive-`init` note above.
    public init(_ pattern: String) {
        segments = pattern
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { rawSegment -> Segment in
                if rawSegment.hasPrefix(":") {
                    .parameter(String(rawSegment.dropFirst()))
                } else {
                    .literal(String(rawSegment))
                }
            }
    }

    /// Tests whether `link` satisfies this pattern and, if so, returns the
    /// merged path + query parameters. Returns `nil` on any mismatch —
    /// wrong segment count, or a literal segment that doesn't match — and
    /// never a partially-populated ``DeepLinkParams``: nothing captured
    /// while walking a since-failed pattern ever escapes this function.
    public func match(_ link: DeepLink) -> DeepLinkParams? {
        guard segments.count == link.path.count else {
            return nil
        }

        var pathParameters: [String: String] = [:]
        for (segment, value) in zip(segments, link.path) {
            switch segment {
            case let .literal(literal):
                guard literal.lowercased() == value.lowercased() else {
                    return nil
                }

            case let .parameter(name):
                pathParameters[name] = value
            }
        }

        var merged = link.query
        for (name, value) in pathParameters {
            merged[name] = value
        }
        return DeepLinkParams(merged)
    }
}
