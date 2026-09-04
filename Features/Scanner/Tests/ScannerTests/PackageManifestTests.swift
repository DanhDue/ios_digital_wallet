import Foundation
import XCTest

/// Source-level guard for Source Spec §11 / ArchTests K1: `ScannerFeature`
/// depends on `Platform`, `Framework`, `AppUIKit` — never `Network`, never
/// another Feature package.
final class PackageManifestTests: XCTestCase {
    private func manifestText(file: StaticString = #filePath) throws -> String {
        let url = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent() // ScannerFeatureTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ScannerFeature
            .appendingPathComponent("Package.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testManifestDeclaresPlatformFrameworkAppUIKitPathDependencies() throws {
        let text = try manifestText()
        for dependency in ["../../Packages/Platform", "../../Packages/Framework", "../../Packages/AppUIKit"] {
            XCTAssertTrue(
                text.contains(#".package(path: "\#(dependency)")"#),
                "Package.swift must declare the \(dependency) path dependency"
            )
        }
    }

    func testManifestDeclaresNoNetworkDependency() throws {
        let text = try manifestText()
        XCTAssertFalse(text.contains("../../Packages/Network"), "Scanner has no network — must not depend on Network")
        XCTAssertFalse(text.contains(#"package: "Network""#), "Scanner has no network — must not link Network")
    }

    func testManifestDeclaresNoOtherFeaturePackageDependency() throws {
        let text = try manifestText()
        for forbidden in ["Settings", "../Settings", "Features/Settings"] {
            XCTAssertFalse(text.contains(forbidden), "Scanner must not depend on \(forbidden)")
        }
    }
}
