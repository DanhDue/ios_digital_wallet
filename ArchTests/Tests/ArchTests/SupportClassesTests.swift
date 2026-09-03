import ArchTestSupport
import Foundation
import XCTest

/// Unit coverage for the `ArchTestSupport` parsing helpers. These run against
/// in-memory fixtures, not the repo tree, so they stay fast and deterministic.
final class SupportClassesTests: XCTestCase {
    // MARK: RepoRoot

    func testRepoRootContainsExpectedManifests() {
        for manifest in ["Workspace.swift", "Project.swift", "Tuist.swift"] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: RepoRoot.url(for: manifest).path),
                "expected \(manifest) at the resolved repo root"
            )
        }
    }

    // MARK: SyntaxScanner

    func testSyntaxScannerExtractsImports() {
        let source = """
        import Foundation
        @testable import SwiftUI
        import struct Combine.Just
        let value = 1
        """
        let tree = SyntaxScanner.parse(source: source)
        XCTAssertEqual(
            SyntaxScanner.importedModuleNames(in: tree),
            ["Foundation", "SwiftUI", "Combine.Just"]
        )
    }

    func testSyntaxScannerExtractsTopLevelDeclarations() {
        let source = """
        import Foundation

        public final class HomeViewModel: MviViewModel, Sendable {}
        struct HomeState {}
        enum HomeAction {}
        protocol HomeRepository {}
        func freeFunction() {}
        typealias Handler = () -> Void
        extension HomeState: Equatable {}
        """
        let decls = SyntaxScanner.topLevelDeclarations(in: SyntaxScanner.parse(source: source))

        let viewModel = try? XCTUnwrap(decls.first { $0.name == "HomeViewModel" })
        XCTAssertEqual(viewModel?.kind, "class")
        XCTAssertEqual(viewModel?.modifiers, ["public", "final"])
        XCTAssertEqual(viewModel?.inheritedTypeNames, ["MviViewModel", "Sendable"])

        XCTAssertEqual(decls.first { $0.name == "HomeState" }?.kind, "struct")
        XCTAssertEqual(decls.first { $0.kind == "func" }?.name, "freeFunction")
        XCTAssertEqual(decls.first { $0.kind == "typealias" }?.name, "Handler")

        let ext = decls.first { $0.kind == "extension" }
        XCTAssertEqual(ext?.name, "HomeState")
        XCTAssertEqual(ext?.inheritedTypeNames, ["Equatable"])
    }

    func testSyntaxScannerSwiftFilesReturnsEmptyForMissingDirectory() {
        let missing = RepoRoot.url(for: "does/not/exist")
        XCTAssertTrue(SyntaxScanner.swiftFiles(under: missing).isEmpty)
    }

    // MARK: Baseline

    func testBaselineParsesEntriesIgnoringCommentsAndBlankLines() {
        let contents = """
        # a comment
          # indented comment

        K3 : Packages/Features/ScannerFeature/Sources/Domain/Bad.swift
        K4:Packages/Features/SettingsFeature/Sources/Data/Leak.swift
        malformed-line-without-separator
        :missing-rule
        K9:
        """
        let baseline = Baseline.parse(contents)
        XCTAssertEqual(baseline.count, 2)
        XCTAssertTrue(baseline.isBaselined(
            rule: "K3",
            path: "Packages/Features/ScannerFeature/Sources/Domain/Bad.swift"
        ))
        XCTAssertTrue(baseline.isBaselined(
            rule: "K4",
            path: "Packages/Features/SettingsFeature/Sources/Data/Leak.swift"
        ))
        XCTAssertFalse(baseline.isBaselined(rule: "K3", path: "some/other/File.swift"))
    }

    func testBaselineEmptyContentsBaselinesNothing() {
        XCTAssertEqual(Baseline.parse("").count, 0)
        XCTAssertEqual(Baseline.parse("\n#only a comment\n").count, 0)
    }

    func testCheckedInBaselineFileIsEmpty() {
        XCTAssertEqual(Baseline.load().count, 0, "ArchTests/baseline.txt must stay empty (greenfield repo)")
    }

    // MARK: BoundaryWhitelist

    func testBoundaryWhitelistParsesEdgesIgnoringCommentsAndBlankLines() {
        let contents = """
        # allowed edges

        ScannerFeature->SettingsFeature
          SettingsFeature -> ScannerFeature
        malformed line
        A->
        ->B
        A->B->C
        """
        let whitelist = BoundaryWhitelist.parse(contents)
        XCTAssertEqual(whitelist.count, 2)
        XCTAssertTrue(whitelist.isAllowed(from: "ScannerFeature", to: "SettingsFeature"))
        XCTAssertTrue(whitelist.isAllowed(from: "SettingsFeature", to: "ScannerFeature"))
        XCTAssertFalse(whitelist.isAllowed(from: "SettingsFeature", to: "PaymentsFeature"))
    }

    func testBoundaryWhitelistEmptyContentsAllowsNothing() {
        XCTAssertEqual(BoundaryWhitelist.parse("").count, 0)
        XCTAssertFalse(BoundaryWhitelist.parse("").isAllowed(from: "A", to: "B"))
    }

    func testCheckedInWhitelistFileIsEmpty() {
        XCTAssertEqual(
            BoundaryWhitelist.load().count,
            0,
            "scripts/module_boundary_whitelist.txt must stay empty (greenfield repo)"
        )
    }
}
