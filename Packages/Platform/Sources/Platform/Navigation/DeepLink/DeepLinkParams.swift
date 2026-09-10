import Foundation

/// The parameters a ``DeepLinkPattern`` yields when it matches a
/// ``DeepLink`` (Source Spec §4.2): path-segment captures merged with the
/// link's query items.
///
/// **Merge rule.** Path parameters win on a name collision with a query
/// item. A path segment is structural and authored by the pattern; a query
/// item arrives from outside the app and must never be able to shadow it —
/// without this rule `/tx/:id?id=evil` would be ambiguous about which `id`
/// wins.
///
/// **`Sendable`** — the only stored property is a `[String: String]`, so a
/// matched params value may be handed across isolation boundaries.
public struct DeepLinkParams: Equatable, Sendable {
    private let values: [String: String]

    /// Builds a params value directly from a merged dictionary. Not
    /// `public`: the only supported way to produce a `DeepLinkParams` outside
    /// this file is `DeepLinkPattern.match(_:)`. Internal visibility still
    /// lets `PlatformTests` construct expected values via `@testable import
    /// Platform`, exactly as the rest of the package's test suite already
    /// does.
    init(_ values: [String: String] = [:]) {
        self.values = values
    }

    /// Looks up a single parameter by name, whether it came from a path
    /// segment or a query item. Returns `nil` when `key` is absent — a
    /// present-but-empty value (`""`) is returned as `""`, never `nil`.
    public subscript(_ key: String) -> String? {
        values[key]
    }
}
