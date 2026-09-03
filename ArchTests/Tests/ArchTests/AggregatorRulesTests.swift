import ArchTestSupport
import Foundation
import XCTest

/// **K6** — only the `App` target aggregates more than one feature; `Shell`
/// aggregates zero (Source Spec §9.2, Changelog #6).
///
/// The `App` composition root is the sole place feature modules are named; the
/// `Shell` is feature-blind and resolves tab content only through
/// `AppRouter` / `RouteProvider`.
///
/// Enforced with an empty baseline. A `Feature` dependency injected into
/// `Packages/Shell/Package.swift` must make
/// `testK6_ShellManifestDeclaresNoFeatureDependency` fail.
final class AggregatorRulesTests: XCTestCase {
    // MARK: K6 — Shell depends on zero features

    func testK6_ShellManifestDeclaresNoFeatureDependency() throws {
        let manifest = try manifestSource(forPackage: "Shell")
        for feature in try featurePackageNames() {
            XCTAssertFalse(
                manifest.contains("/\(feature)\"") || manifest.contains("package: \"\(feature)\""),
                "K6: Packages/Shell/Package.swift must not depend on feature package \(feature)"
            )
        }
        XCTAssertFalse(
            manifest.contains("Features/"),
            "K6: Shell must not reference the Packages/Features/ tree at all"
        )
    }

    func testK6_NoShellSourceImportsAFeatureModule() throws {
        let names = try Set(featurePackageNames())
        var offenders: [String] = []
        for file in SyntaxScanner.swiftFiles(under: RepoRoot.url(for: "Packages/Shell/Sources")) {
            let imports = BoundaryRulesTests.headModules(ofFileAt: file)
            let hits = imports.intersection(names)
            if !hits.isEmpty {
                let relative = file.path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
                offenders.append("\(relative) — imports \(hits.sorted().joined(separator: ", "))")
            }
        }
        XCTAssertEqual(offenders, [], "K6: Shell must stay feature-blind:\n" + offenders.joined(separator: "\n"))
    }

    // MARK: K6 — every feature package aggregates zero features

    func testK6_NoFeaturePackageAggregatesAnotherFeature() throws {
        let names = try featurePackageNames()
        var offenders: [String] = []
        for from in names {
            let manifest = try manifestSource(forFeature: from)
            for other in names where other != from {
                if manifest.contains("/\(other)\"") || manifest.contains("package: \"\(other)\"") {
                    offenders.append("\(from) -> \(other)")
                }
            }
        }
        XCTAssertEqual(
            offenders, [],
            "K6: a feature package aggregates another feature:\n" + offenders.joined(separator: "\n")
        )
    }

    // MARK: K6 — the App target is allowed to (and does) aggregate many

    func testK6_AppTargetIsTheSoleMultiFeatureAggregator() throws {
        let projectManifest = try String(contentsOf: RepoRoot.url(for: "Project.swift"), encoding: .utf8)
        let names = try featurePackageNames()
        let aggregated = names.filter { projectManifest.contains("\"\($0)\"") }
        XCTAssertGreaterThan(
            aggregated.count, 1,
            "K6: the App target is expected to aggregate every feature (\(names.joined(separator: ", ")))"
        )
    }

    // MARK: Helpers

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

    private func manifestSource(forPackage package: String) throws -> String {
        try String(contentsOf: RepoRoot.url(for: "Packages/\(package)/Package.swift"), encoding: .utf8)
    }

    private func manifestSource(forFeature feature: String) throws -> String {
        try String(contentsOf: RepoRoot.url(for: "Packages/Features/\(feature)/Package.swift"), encoding: .utf8)
    }
}
