import Foundation
import XCTest

/// Source-level guard for Source Spec Changelog #6 / ArchTests K6: `Shell`
/// depends on `Platform`, `Framework`, `AppUIKit` — and never a Feature package.
final class PackageManifestTests: XCTestCase {
    private func manifestText(file: StaticString = #filePath) throws -> String {
        let url = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent() // ShellTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Shell
            .appendingPathComponent("Package.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testManifestDeclaresPlatformFrameworkAppUIKitPathDependencies() throws {
        let text = try manifestText()
        for dependency in ["../Platform", "../Framework", "../AppUIKit"] {
            XCTAssertTrue(
                text.contains(#".package(path: "\#(dependency)")"#),
                "Package.swift must declare the \(dependency) path dependency"
            )
        }
    }

    func testManifestDeclaresNoFeaturePackageDependency() throws {
        let text = try manifestText()
        for forbidden in ["Settings", "Scanner", "Features"] {
            XCTAssertFalse(text.contains(forbidden), "Shell must not depend on \(forbidden)")
        }
    }
}
