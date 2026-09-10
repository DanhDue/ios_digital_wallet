import Foundation

/// A raw `URL` normalised into the segment/query shape the deep-link router
/// matches against (Source Spec §4.1). `DeepLinkPattern` (Task 3) and the
/// router engine (Task 5) consume this type; `DeepLink` itself does no
/// matching — it only normalises.
///
/// **Normalisation rules:**
///
/// | Input shape | Rule |
/// |---|---|
/// | Custom scheme — `app://settings/language` | host is prepended as the first segment ⇒ `["settings", "language"]` |
/// | Universal Link — `https://example.com/settings/language` | host is discarded ⇒ `["settings", "language"]` |
/// | Trailing / doubled slashes | empty path segments are removed |
/// | Case | segments are stored verbatim, never lowercased |
/// | Percent-encoding | each path segment is decoded individually; query values are decoded via `queryItems` |
/// | Duplicate query keys | last one wins — never silently ignored |
/// | Query item with no value (`?flag`) | maps to `""` |
/// | `URLComponents(url:resolvingAgainstBaseURL: false)` fails | `init?` returns `nil` |
///
/// An empty normalised path (from `app://`) is legal and later matches the
/// pattern `"/"`.
///
/// **Why the host is prepended only for custom schemes.** For a custom
/// scheme the host component carries the first meaningful segment — in
/// `app://settings/language`, `"settings"` is not a domain. For `http`/
/// `https` the host is a real domain and would be noise in the segment
/// list, so it is discarded there instead. The scheme comparison is
/// case-insensitive: `HTTPS://` still counts as a web scheme.
///
/// **Why case is preserved verbatim.** `DeepLinkPattern` (Task 3) lowercases
/// only when comparing a *literal* segment, so a captured parameter value
/// keeps its original case.
///
/// **Why percent-encoding is decoded per segment, not on the whole path.**
/// Splitting the fully-decoded path on `/` would treat a percent-encoded
/// slash (`%2F`) as a segment boundary, which is wrong per RFC 3986 §3.3 —
/// `%2F` is data *within* a segment, not a delimiter. Splitting
/// `percentEncodedPath` first, then decoding each segment afterward, keeps
/// `%2F` inside its segment (`"a%2Fb"` decodes to the single segment
/// `"a/b"`, never two segments `"a"`, `"b"`). This matters concretely for
/// Task 7's `/scanner/result/:code` pattern: a scanned payload containing
/// `/` arrives percent-encoded and must still match as one captured segment.
///
/// **No scheme or host validation.** iOS only ever delivers URLs for schemes
/// and associated domains the app registered, so re-validating here would be
/// redundant and would break Universal Links for consumers who enable them.
///
/// **`Sendable`** — every stored property is a value type, so a normalised
/// link may be handed across isolation boundaries by a consuming project.
public struct DeepLink: Equatable, Sendable {
    /// The original, unmodified URL this link was normalised from.
    public let url: URL

    /// Normalised path segments, empties removed, stored verbatim (never
    /// lowercased). For a custom scheme this includes the host as the first
    /// element; for an `http`/`https` scheme the host is excluded.
    public let path: [String]

    /// Query parameters, decoded. A duplicate key keeps its last occurrence;
    /// a valueless item (`?flag`) maps to `""`.
    public let query: [String: String]

    /// Normalises `url`, or returns `nil` when it cannot be decomposed into
    /// components at all (`URLComponents(url:resolvingAgainstBaseURL: false)`
    /// fails).
    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        self.url = url
        path = Self.normalisedSegments(for: components)
        query = Self.normalisedQuery(for: components)
    }

    /// The http/https ⇒ host-is-noise rule, isolated behind a name so the
    /// asymmetry with custom schemes (host-is-the-first-segment) reads as a
    /// documented decision at the call site, not an inline `if`.
    private static func isWebScheme(_ scheme: String?) -> Bool {
        switch scheme?.lowercased() {
        case "http", "https":
            true
        default:
            false
        }
    }

    /// Splits `components.percentEncodedPath` (still encoded) on `/`,
    /// dropping empty segments (trailing/doubled slashes), decodes each
    /// segment individually, then prepends the host for every scheme except
    /// `http`/`https`, where the host is domain noise.
    ///
    /// Splitting **before** decoding — rather than decoding the whole path
    /// and splitting the result — is what keeps a percent-encoded slash
    /// (`%2F`) inside its segment instead of it being mistaken for a literal
    /// path separator (RFC 3986 §3.3).
    private static func normalisedSegments(for components: URLComponents) -> [String] {
        var segments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { encodedSegment -> String in
                let raw = String(encodedSegment)
                return raw.removingPercentEncoding ?? raw
            }

        if !isWebScheme(components.scheme), let host = components.host, !host.isEmpty {
            segments.insert(host, at: 0)
        }

        return segments
    }

    /// Folds `queryItems` into a dictionary: later items win on key
    /// collision, and a valueless item (`?flag`) contributes `""`.
    private static func normalisedQuery(for components: URLComponents) -> [String: String] {
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }
        return query
    }
}
