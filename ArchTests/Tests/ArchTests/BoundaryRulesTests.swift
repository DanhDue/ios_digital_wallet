import ArchTestSupport
import Foundation
import XCTest

/// **K1** — no feature package depends on another feature package
/// (Source Spec §9.2, §9.3, Changelog #10).
///
/// Three nets, all enforced with an empty baseline and an empty whitelist:
///   1. every `Features/<X>/Package.swift` names no other feature
///      package (neither a `.package(path: "../<Y>")` nor a
///      `.product(... package: "<Y>")`);
///   2. no `Features/<X>/Sources/**` file `import`s another feature
///      module;
///   3. `scripts/check_module_boundaries.sh` exits 0.
///
/// A violation injected into any feature manifest (e.g.
/// `Settings` gaining a dependency on `Scanner`) must make
/// `testK1_NoFeatureManifestDependsOnAnotherFeature` fail and name the edge.
final class BoundaryRulesTests: XCTestCase {
    // MARK: K1 — manifest assertion

    func testK1_NoFeatureManifestDependsOnAnotherFeature() throws {
        let names = try Self.featurePackageNames()
        XCTAssertGreaterThanOrEqual(names.count, 2, "expected at least Scanner + Settings")

        var offenders: [String] = []
        let whitelist = BoundaryWhitelist.load()

        for from in names {
            let manifest = try Self.manifestSource(for: from)
            for other in names where other != from {
                // The two real SPM ways one package pulls in another: a path
                // dependency (`.package(path: "../<Other>")`) or a product
                // reference (`.product(name: ..., package: "<Other>")`).
                let dependsOnOther =
                    manifest.contains("/\(other)\"")
                        || manifest.contains("package: \"\(other)\"")
                if dependsOnOther, !whitelist.isAllowed(from: from, to: other) {
                    offenders.append("\(from) -> \(other)")
                }
            }
        }

        XCTAssertEqual(
            offenders, [],
            "K1: a feature package must not depend on another feature package:\n"
                + offenders.joined(separator: "\n")
        )
    }

    // MARK: K1 — import scan (defence in depth, mirrors the shell guard)

    func testK1_NoFeatureSourceImportsAnotherFeatureModule() throws {
        let names = try Set(Self.featurePackageNames())
        let baseline = Baseline.load()
        var offenders: [String] = []

        for from in names {
            let sources = RepoRoot.url(for: "Features/\(from)/Sources")
            for file in SyntaxScanner.swiftFiles(under: sources) {
                let imports = Self.headModules(ofFileAt: file)
                let crossFeature = imports.intersection(names).subtracting([from])
                guard !crossFeature.isEmpty else { continue }
                let relative = file.path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
                if baseline.isBaselined(rule: "K1", path: relative) {
                    continue
                }
                offenders.append("\(relative) — imports \(crossFeature.sorted().joined(separator: ", "))")
            }
        }

        XCTAssertEqual(
            offenders, [],
            "K1: no feature source may import another feature module:\n" + offenders.joined(separator: "\n")
        )
    }

    // MARK: K1 — the shell guard agrees

    func testK1_CheckModuleBoundariesScriptExitsZero() throws {
        let script = RepoRoot.url(for: "scripts/check_module_boundaries.sh").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, "check_module_boundaries.sh must exit 0:\n\(output)")
    }

    func testK1_WhitelistIsEmpty() {
        XCTAssertEqual(BoundaryWhitelist.load().count, 0, "scripts/module_boundary_whitelist.txt must stay empty")
    }

    // MARK: Helpers

    static func featurePackageDirectories() throws -> [URL] {
        let dir = RepoRoot.url(for: "Features")
        let entries = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.path < $1.path }
    }

    static func featurePackageNames() throws -> [String] {
        try featurePackageDirectories().map(\.lastPathComponent)
    }

    static func manifestSource(for feature: String) throws -> String {
        try String(
            contentsOf: RepoRoot.url(for: "Features/\(feature)/Package.swift"),
            encoding: .utf8
        )
    }

    /// Head module name of every `import` in the file at `url`
    /// (`import struct Foo.Bar` → `Foo`). Empty if the file cannot be parsed.
    static func headModules(ofFileAt url: URL) -> Set<String> {
        guard let tree = try? SyntaxScanner.parse(fileAt: url) else { return [] }
        let names = SyntaxScanner.importedModuleNames(in: tree)
        return Set(names.map { String($0.split(separator: ".").first ?? "") })
    }
}
