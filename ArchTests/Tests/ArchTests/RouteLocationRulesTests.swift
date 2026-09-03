import ArchTestSupport
import Foundation
import XCTest

/// **K9** — an `AppRoute` value used by more than one feature is declared in
/// `Platform/Navigation/AppRoutes.swift`, not inside a feature (Source Spec
/// §9.2, §6.2).
///
/// A feature MAY declare its own private `AppRoute` types (screen-local
/// destinations). What it must not do is declare an `AppRoute` type that another
/// feature also references — that shared vocabulary belongs in `Platform`.
///
/// Mechanism: find every `AppRoute`-conforming type declared under a
/// `Packages/Features/*/Sources/**` tree (AST inheritance clause + a regex net
/// for types nested inside a namespace `enum`). For each, if its bare name is
/// referenced as an identifier token in a *different* feature's sources, and it
/// is not (re)declared in `Platform/AppRoutes.swift`, that is a K9 violation.
final class RouteLocationRulesTests: XCTestCase {
    // MARK: K9 — no feature-declared AppRoute is shared across features

    func testK9_FeatureDeclaredAppRoutesAreNotReferencedByOtherFeatures() throws {
        let features = try featurePackageNames()
        let baseline = Baseline.load()

        // feature name -> set of AppRoute type names it declares
        var declared: [String: Set<String>] = [:]
        for feature in features {
            declared[feature] = appRouteTypeNames(
                inSourcesOf: RepoRoot.url(for: "Packages/Features/\(feature)/Sources")
            )
        }

        let platformRoutes = try String(
            contentsOf: RepoRoot.url(for: "Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift"),
            encoding: .utf8
        )

        var offenders: [String] = []
        for (owner, typeNames) in declared {
            for typeName in typeNames {
                if baseline.isBaselined(rule: "K9", path: "\(owner)/\(typeName)") {
                    continue
                }
                // Declared in Platform too? Then it is fine wherever it is used.
                if platformRoutes.contains(typeName) {
                    continue
                }
                for other in declared.keys where other != owner {
                    if sourcesReferenceIdentifier(
                        typeName,
                        under: RepoRoot.url(for: "Packages/Features/\(other)/Sources")
                    ) {
                        offenders.append(
                            "\(owner) declares AppRoute `\(typeName)` which \(other) also references "
                                + "— move it to Platform/AppRoutes.swift"
                        )
                    }
                }
            }
        }

        XCTAssertEqual(offenders, [], "K9 violations:\n" + offenders.joined(separator: "\n"))
    }

    // MARK: K9 — the shared route roots live in Platform

    func testK9_SharedRouteRootsAreDeclaredInPlatform() throws {
        let appRoutes = try String(
            contentsOf: RepoRoot.url(for: "Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift"),
            encoding: .utf8
        )
        for root in ["SettingsRoot", "ScannerRoot"] {
            XCTAssertTrue(
                appRoutes.contains("struct \(root)"),
                "K9: AppRoutes.\(root) must be declared in Platform/Navigation/AppRoutes.swift"
            )
        }
    }

    func testK9_NoFeatureRedeclaresAScreenRootFromAppRoutes() throws {
        var offenders: [String] = []
        for feature in try featurePackageNames() {
            let names = appRouteTypeNames(inSourcesOf: RepoRoot.url(for: "Packages/Features/\(feature)/Sources"))
            for shared in ["SettingsRoot", "ScannerRoot"] where names.contains(shared) {
                offenders.append("\(feature) re-declares AppRoutes.\(shared)")
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: Helpers

    /// AppRoute-conforming type names declared under `sources`. Uses the AST for
    /// top-level declarations and a regex for types nested in a namespace enum.
    private func appRouteTypeNames(inSourcesOf sources: URL) -> Set<String> {
        var names: Set<String> = []
        let declPattern = try? NSRegularExpression(
            pattern: #"(?:struct|enum|class)\s+([A-Za-z_]\w*)\s*:\s*[^\{]*\bAppRoute\b"#
        )
        for file in SyntaxScanner.swiftFiles(under: sources) {
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

    private func sourcesReferenceIdentifier(_ identifier: String, under root: URL) -> Bool {
        for file in SyntaxScanner.swiftFiles(under: root) {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let tokens = Set(source.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))
            if tokens.contains(identifier) {
                return true
            }
        }
        return false
    }

    private func featurePackageNames() throws -> [String] {
        let dir = RepoRoot.url(for: "Packages/Features")
        let entries = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map(\.lastPathComponent)
            .sorted()
    }
}
