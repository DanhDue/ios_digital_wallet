import Foundation

/// Parser + lookup for `ArchTests/baseline.txt` — the set of pre-existing
/// architecture-rule violations that an *enforced* rule tolerates until its
/// dedicated clean-up task (Source Spec §9.2).
///
/// Grammar:
/// - one entry per line: `ruleId:relative/path/to/File.swift`;
/// - blank lines and lines whose first non-blank character is `#` are ignored;
/// - leading / trailing whitespace on the line and around each side is trimmed;
/// - a malformed non-comment line (no `:`, or an empty side) is skipped.
///
/// An empty / missing file baselines nothing.
public struct Baseline: Equatable {
    private let entries: Set<String>

    public init(entries: Set<String> = []) {
        self.entries = entries
    }

    /// Loads and parses `ArchTests/baseline.txt` from the repository root.
    public static func load() -> Baseline {
        let url = RepoRoot.url(for: "ArchTests/baseline.txt")
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return Baseline()
        }
        return parse(contents)
    }

    /// Parses raw `contents`; see the type doc for the grammar.
    public static func parse(_ contents: String) -> Baseline {
        var entries: Set<String> = []
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            let parts = line
                .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                .map { part in part.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { continue }
            entries.insert("\(parts[0]):\(parts[1])")
        }
        return Baseline(entries: entries)
    }

    /// Whether `path` is a baselined violation of `rule`.
    public func isBaselined(rule: String, path: String) -> Bool {
        entries.contains("\(rule):\(path)")
    }

    /// Number of baselined entries.
    public var count: Int {
        entries.count
    }
}
