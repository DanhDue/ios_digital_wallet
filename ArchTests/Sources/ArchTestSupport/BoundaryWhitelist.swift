import Foundation

/// Parser + lookup for `scripts/module_boundary_whitelist.txt` — the set of
/// temporarily-allowed cross-feature import edges (ArchTests K1 / Source Spec
/// §9.3). Mirrors the shell guard `scripts/check_module_boundaries.sh`.
///
/// Grammar:
/// - one entry per line: `FeatureA->FeatureB`;
/// - blank lines and lines whose first non-blank character is `#` are ignored;
/// - whitespace around the line and around each side is trimmed;
/// - a malformed non-comment line (not exactly one `->`, or an empty side) is
///   skipped.
///
/// An empty / missing file allows nothing.
public struct BoundaryWhitelist: Equatable {
    /// A directed, temporarily-allowed cross-feature edge, `from -> to`.
    public struct Edge: Hashable {
        public let from: String
        public let to: String

        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    private let edges: Set<Edge>

    public init(edges: Set<Edge> = []) {
        self.edges = edges
    }

    /// Loads and parses `scripts/module_boundary_whitelist.txt` from the
    /// repository root.
    public static func load() -> BoundaryWhitelist {
        let url = RepoRoot.url(for: "scripts/module_boundary_whitelist.txt")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return BoundaryWhitelist()
        }
        return parse(contents)
    }

    /// Parses raw `contents`; see the type doc for the grammar.
    public static func parse(_ contents: String) -> BoundaryWhitelist {
        var edges: Set<Edge> = []
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            let parts = line
                .components(separatedBy: "->")
                .map { part in part.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { continue }
            edges.insert(Edge(from: parts[0], to: parts[1]))
        }
        return BoundaryWhitelist(edges: edges)
    }

    /// Whether an import edge `from -> to` is explicitly allowed.
    public func isAllowed(from: String, to: String) -> Bool {
        edges.contains(Edge(from: from, to: to))
    }

    /// Number of whitelisted edges.
    public var count: Int {
        edges.count
    }
}
