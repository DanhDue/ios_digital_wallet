import Foundation
import XCTest

/// Source-level guard for Source Spec Changelog #7: `Platform` depends on `Core`
/// **only** — never on `Framework` (nor `Network` / `AppUIKit`).
final class PackageDependenciesTests: XCTestCase {
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PlatformTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Platform
    }

    func testNoSourceFileImportsFramework() throws {
        let sources = packageRoot.appendingPathComponent("Sources")
        let files = try swiftFiles(under: sources)

        XCTAssertFalse(files.isEmpty, "found no Swift sources under \(sources.path)")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                text.contains("import Framework"),
                "\(file.lastPathComponent) imports Framework — Platform must depend on Core only"
            )
            XCTAssertFalse(
                text.contains("import Network"),
                "\(file.lastPathComponent) imports Network"
            )
        }
    }

    func testPackageManifestDeclaresCoreAsTheOnlyPackageDependency() throws {
        let manifest = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            manifest.contains(#".package(path: "../Core")"#),
            "Package.swift must declare the Core path dependency"
        )
        for forbidden in ["../Framework", "../Network", "../AppUIKit"] {
            XCTAssertFalse(
                manifest.contains(forbidden),
                "Package.swift must not depend on \(forbidden)"
            )
        }
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
