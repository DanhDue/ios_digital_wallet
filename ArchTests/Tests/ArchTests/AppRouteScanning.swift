import ArchTestSupport
import Foundation

/// Shared "what is an `AppRoute` type declared here" traversal, used by both
/// **K9** (`RouteLocationRulesTests`) and **K10.2** (`DeepLinkRulesTests`) so
/// the two rules ask this question against a single implementation rather
/// than maintaining two divergent copies.
enum AppRouteScanning {
    /// `AppRoute`-conforming type names declared in `files`. Uses the AST for
    /// top-level declarations and a regex for types nested inside a
    /// namespace `enum` (e.g. `AppRoutes.SettingsRoot`, which
    /// `SyntaxScanner.topLevelDeclarations` does not descend into).
    static func appRouteTypeNames(in files: [URL]) -> Set<String> {
        var names: Set<String> = []
        let declPattern = try? NSRegularExpression(
            pattern: #"(?:struct|enum|class)\s+([A-Za-z_]\w*)\s*:\s*[^\{]*\bAppRoute\b"#
        )
        for file in files {
            if let tree = try? SyntaxScanner.parse(fileAt: file) {
                let conformers = SyntaxScanner.topLevelDeclarations(in: tree)
                    .filter { $0.inheritedTypeNames.contains { name in name.hasPrefix("AppRoute") } }
                for decl in conformers {
                    names.insert(decl.name)
                }
            }
            guard let source = try? String(contentsOf: file, encoding: .utf8), let declPattern else { continue }
            let range = NSRange(source.startIndex..., in: source)
            for match in declPattern.matches(in: source, range: range) {
                if let nameRange = Range(match.range(at: 1), in: source) {
                    names.insert(String(source[nameRange]))
                }
            }
        }
        return names
    }
}
