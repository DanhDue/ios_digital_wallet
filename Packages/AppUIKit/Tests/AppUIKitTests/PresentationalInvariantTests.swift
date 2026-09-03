import XCTest
@testable import AppUIKit

/// §4.3 hard invariants for `AppUIKit`:
/// * purely presentational — no observable-object machinery in the sources;
/// * depends on `Core` only — never `Framework`.
final class PresentationalInvariantTests: XCTestCase {
    private func allSourceFiles() -> [URL] {
        let files = PackageSources.swiftFiles(under: PackageSources.sourcesDir)
        XCTAssertFalse(files.isEmpty, "expected .swift files under Sources/AppUIKit")
        return files
    }

    func testNoSourceFileUsesObservableObjectMachinery() throws {
        let banned = ["ObservableObject", "@StateObject", "@ObservedObject"]
        for file in allSourceFiles() {
            let source = try PackageSources.contents(of: file)
            for token in banned {
                XCTAssertFalse(
                    source.contains(token),
                    "\(file.lastPathComponent) must not contain `\(token)` — AppUIKit is purely presentational"
                )
            }
        }
    }

    func testNoSourceFileImportsFramework() throws {
        for file in allSourceFiles() {
            let source = try PackageSources.contents(of: file)
            XCTAssertFalse(
                source.contains("import Framework"),
                "\(file.lastPathComponent) imports Framework — forbidden (§4.2)"
            )
        }
    }

    func testPackageManifestDoesNotDependOnFramework() throws {
        let manifest = try PackageSources.contents(of: PackageSources.manifest)
        XCTAssertFalse(
            manifest.contains("\"../Framework\""),
            "Package.swift must NOT declare a dependency on Framework"
        )
        XCTAssertFalse(
            manifest.contains("package: \"Framework\""),
            "Package.swift must NOT link the Framework product"
        )
        XCTAssertTrue(manifest.contains("\"../Core\""), "Package.swift must depend on Core")
    }

    func testEveryComponentHasAnXcodePreview() throws {
        let componentFiles = PackageSources.swiftFiles(under: PackageSources.componentsDir)
        XCTAssertEqual(componentFiles.count, 5, "expected 5 component files")
        for file in componentFiles {
            let source = try PackageSources.contents(of: file)
            XCTAssertTrue(
                source.contains("#Preview"),
                "\(file.lastPathComponent) must declare an Xcode #Preview"
            )
        }
    }

    func testComponentsOnlyUseBindingOrStateForLocalState() throws {
        let componentFiles = PackageSources.swiftFiles(under: PackageSources.componentsDir)
        for file in componentFiles {
            let source = try PackageSources.contents(of: file)
            XCTAssertFalse(source.contains("@EnvironmentObject"), "\(file.lastPathComponent) uses @EnvironmentObject")
        }
    }
}
