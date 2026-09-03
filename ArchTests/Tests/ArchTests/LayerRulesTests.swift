import ArchTestSupport
import Foundation
import XCTest

/// Clean-Architecture layer rules (Source Spec §9.2, §4.4).
///
/// - **K2** — inside a feature package, `Presentation/**` must not reach into
///   `Data/**`, and `Domain/**` must not reach into `Presentation/**` or
///   `Data/**`.
/// - **K3** — any file on a `/Domain/` path is pure Swift: no `import SwiftUI`,
///   `import UIKit`, or `import Combine`.
///
/// No feature packages exist yet, so both rules scan, find nothing, and pass —
/// they are *armed* here so the first feature package (Task 11 / Task 12) is
/// born under enforcement rather than retrofitted.
///
/// ### K2 limitation (pragmatic v1)
/// A feature is a single SPM module, so "Presentation imports Data" is never a
/// real `import` statement — it is a *type reference* across folders. Without a
/// full type-resolution pass this rule uses two cheap heuristics:
///   1. no `/Presentation/` or `/Domain/` file imports a module whose name ends
///      in `Data` / `Domain` / `Presentation` (defensive; sub-module layouts);
///   2. no `/Presentation/` file textually references a type *declared* under
///      that feature's `/Data/`, and no `/Domain/` file references a type
///      declared under `/Data/` or `/Presentation/`.
/// Heuristic 2 is identifier-substring matching: it can miss a reference behind a
/// `typealias` and can false-positive on a coincidental name collision. The real
/// guard against a Data type leaking into Presentation is **K4** (`internal` in
/// `Data/`, AST-checked in `DeclRulesTests`) plus the SPM dependency graph.
final class LayerRulesTests: XCTestCase {
    private static let uiFrameworks: Set<String> = ["SwiftUI", "UIKit", "Combine"]

    // MARK: K3 — pure-Swift Domain

    func testK3_DomainFilesImportNoUIFramework() {
        let baseline = Baseline.load()
        var offenders: [String] = []
        for file in domainFiles() {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            let imports = Set(SyntaxScanner.importedModuleNames(in: tree).map(headModule))
            let banned = imports.intersection(Self.uiFrameworks).sorted()
            guard !banned.isEmpty else { continue }
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K3", path: relative) {
                continue
            }
            offenders.append("\(relative) — imports \(banned.joined(separator: ", "))")
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "K3: files on a /Domain/ path must not import SwiftUI/UIKit/Combine:\n"
                + offenders.joined(separator: "\n")
        )
    }

    // MARK: K2 — Presentation ⇏ Data; Domain ⇏ Presentation / Data

    func testK2_FeatureLayerBoundariesAreNotCrossed() {
        var offenders: [String] = []

        for feature in featurePackageSourceRoots() {
            let files = SyntaxScanner.swiftFiles(under: feature)
            let dataLayer = files.filter { $0.path.contains("/Data/") }
            let domainLayer = files.filter { $0.path.contains("/Domain/") }
            let presentationLayer = files.filter { $0.path.contains("/Presentation/") }

            // Heuristic 1 — no cross-layer *module* import.
            offenders += moduleImportOffenders(in: presentationLayer, bannedSuffixes: ["Data"])
            offenders += moduleImportOffenders(in: domainLayer, bannedSuffixes: ["Data", "Presentation"])

            // Heuristic 2 — no cross-layer *type reference*.
            let dataTypes = declaredTypeNames(in: dataLayer)
            let presentationTypes = declaredTypeNames(in: presentationLayer)
            offenders += typeReferenceOffenders(
                in: presentationLayer, referencing: dataTypes, layer: "Data", from: "Presentation"
            )
            offenders += typeReferenceOffenders(
                in: domainLayer, referencing: dataTypes, layer: "Data", from: "Domain"
            )
            offenders += typeReferenceOffenders(
                in: domainLayer, referencing: presentationTypes, layer: "Presentation", from: "Domain"
            )
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "K2: feature layer boundary crossed:\n" + offenders.joined(separator: "\n")
        )
    }

    // MARK: File discovery

    /// Every `.swift` file under `Packages/**/Sources/**` whose path contains a
    /// `/Domain/` segment.
    private func domainFiles() -> [URL] {
        SyntaxScanner.swiftFiles(under: RepoRoot.url(for: "Packages"))
            .filter { $0.path.contains("/Sources/") && $0.path.contains("/Domain/") }
    }

    /// `Sources` root of every feature package, or `[]` when none exist yet.
    private func featurePackageSourceRoots() -> [URL] {
        let featuresDir = RepoRoot.url(for: "Packages/Features")
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: featuresDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { $0.appendingPathComponent("Sources") }
            .sorted { $0.path < $1.path }
    }

    // MARK: Heuristics

    private func moduleImportOffenders(in files: [URL], bannedSuffixes: [String]) -> [String] {
        var offenders: [String] = []
        for file in files {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for module in SyntaxScanner.importedModuleNames(in: tree).map(headModule) {
                guard bannedSuffixes.contains(where: { module != $0 && module.hasSuffix($0) }) else { continue }
                offenders.append("\(relativePath(of: file)) — imports \(module)")
            }
        }
        return offenders
    }

    private func declaredTypeNames(in files: [URL]) -> Set<String> {
        let kinds: Set = ["struct", "class", "enum", "actor", "protocol", "typealias"]
        var names: Set<String> = []
        for file in files {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for decl in SyntaxScanner.topLevelDeclarations(in: tree) where kinds.contains(decl.kind) {
                names.insert(decl.name)
            }
        }
        return names
    }

    private func typeReferenceOffenders(
        in files: [URL],
        referencing names: Set<String>,
        layer: String,
        from origin: String
    ) -> [String] {
        guard !names.isEmpty else { return [] }
        var offenders: [String] = []
        for file in files {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let tokens = Set(source.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))
            let hits = names.intersection(tokens).sorted()
            guard !hits.isEmpty else { continue }
            offenders.append(
                "\(relativePath(of: file)) — \(origin) references \(layer) type(s) \(hits.joined(separator: ", "))"
            )
        }
        return offenders
    }

    // MARK: Small helpers

    private func headModule(_ imported: String) -> String {
        String(imported.split(separator: ".").first ?? Substring(imported))
    }

    private func relativePath(of url: URL) -> String {
        url.path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
    }
}
