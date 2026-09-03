import ArchTestSupport
import Foundation
import XCTest

/// The single trivial architecture rule for Phase 0: prove the support layer is
/// wired up end to end against the real repository tree. Real rules (K1–K9)
/// arrive in Task 9 / Task 12.
final class ScopeSanityTest: XCTestCase {
    func testRepoRootResolvesToWorkspaceDirectory() {
        let workspaceManifest = RepoRoot.url.appendingPathComponent("Workspace.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: workspaceManifest.path),
            "RepoRoot.url should point at the repo root that contains Workspace.swift"
        )
        XCTAssertEqual(RepoRoot.path, RepoRoot.url.path)
    }

    func testSyntaxScannerParsesAppSourcesAndFindsSwiftUIImport() throws {
        let appSources = RepoRoot.url(for: "App/Sources")
        let files = SyntaxScanner.swiftFiles(under: appSources)
        XCTAssertFalse(files.isEmpty, "expected at least one .swift file under App/Sources")

        var sawSwiftUIImport = false
        for file in files {
            let tree = try SyntaxScanner.parse(fileAt: file)
            if SyntaxScanner.importedModuleNames(in: tree).contains("SwiftUI") {
                sawSwiftUIImport = true
                break
            }
        }
        XCTAssertTrue(sawSwiftUIImport, "expected an `import SwiftUI` in some file under App/Sources")
    }
}
