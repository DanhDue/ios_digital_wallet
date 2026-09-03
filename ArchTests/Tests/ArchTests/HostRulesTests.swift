import ArchTestSupport
import Foundation
import XCTest

/// Host- / floor-privilege rules (Source Spec §9.2).
///
/// - **K7** — `Core` is the dependency floor: its `Package.swift` declares no
///   sibling infra package and no file under `Packages/Core/Sources/**` imports
///   `Framework` / `Network` / `AppUIKit` / `Platform`.
/// - **AppUIKit ∌ Framework** — the design system stays extractable: its
///   `Package.swift` declares no `Framework` dependency and no source imports it.
///
/// Both are enforced with an empty baseline and must fail, naming the offending
/// file, if a violation is injected.
final class HostRulesTests: XCTestCase {
    private static let coreSiblings = ["Framework", "Network", "AppUIKit", "Platform"]

    // MARK: K7 — Core imports no sibling infra package

    func testK7_CorePackageManifestDeclaresNoSiblingDependency() throws {
        let manifest = try manifestSource(for: "Core")
        for sibling in Self.coreSiblings {
            XCTAssertFalse(
                manifest.contains("../\(sibling)\"") || manifest.contains("package: \"\(sibling)\""),
                "K7: Packages/Core/Package.swift must not depend on sibling package \(sibling)"
            )
        }
    }

    func testK7_CoreSourcesImportNoSiblingInfraModule() {
        let offenders = importOffenders(
            underPackageSources: "Core",
            forbidden: Set(Self.coreSiblings),
            rule: "K7"
        )
        XCTAssertTrue(
            offenders.isEmpty,
            "K7: Core source files must not import \(Self.coreSiblings.joined(separator: "/")). "
                + "Offending files:\n" + offenders.joined(separator: "\n")
        )
    }

    // MARK: AppUIKit ∌ Framework

    func testAppUIKitPackageManifestDeclaresNoFrameworkDependency() throws {
        let manifest = try manifestSource(for: "AppUIKit")
        XCTAssertFalse(
            manifest.contains("../Framework\"") || manifest.contains("package: \"Framework\""),
            "AppUIKit ∌ Framework: Packages/AppUIKit/Package.swift must not depend on Framework"
        )
    }

    func testAppUIKitSourcesDoNotImportFramework() {
        let offenders = importOffenders(
            underPackageSources: "AppUIKit",
            forbidden: ["Framework"],
            rule: "AppUIKit∌Framework"
        )
        XCTAssertTrue(
            offenders.isEmpty,
            "AppUIKit ∌ Framework: no AppUIKit source may `import Framework`. Offending files:\n"
                + offenders.joined(separator: "\n")
        )
    }

    // MARK: Helpers

    private func manifestSource(for package: String) throws -> String {
        let url = RepoRoot.url(for: "Packages/\(package)/Package.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Relative paths of files under `Packages/<package>/Sources` that import any
    /// module in `forbidden` (baseline-exempt entries removed).
    private func importOffenders(
        underPackageSources package: String,
        forbidden: Set<String>,
        rule: String
    ) -> [String] {
        let baseline = Baseline.load()
        let root = RepoRoot.url(for: "Packages/\(package)/Sources")
        var offenders: [String] = []
        for file in SyntaxScanner.swiftFiles(under: root) {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            let imports = Set(SyntaxScanner.importedModuleNames(in: tree).map(headModule))
            guard !imports.isDisjoint(with: forbidden) else { continue }
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: rule, path: relative) {
                continue
            }
            offenders.append(relative)
        }
        return offenders
    }

    private func headModule(_ imported: String) -> String {
        String(imported.split(separator: ".").first ?? Substring(imported))
    }

    private func relativePath(of url: URL) -> String {
        url.path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
    }
}
