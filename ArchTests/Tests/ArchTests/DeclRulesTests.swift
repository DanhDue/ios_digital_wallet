import ArchTestSupport
import Foundation
import XCTest

/// Declaration-shape rules (Source Spec §9.2).
///
/// - **K4** — no top-level type / func / typealias / extension on a `/Data/`
///   path is `public` or `open`; a feature's `Data` layer stays `internal` and
///   is reached only through a `Domain` protocol.
/// - **K5** — naming / conformance conventions for feature-authored types:
///   `*ViewModel` inherits `MviViewModel` / `MvvmViewModel`; `*RouteProvider`
///   conforms to `RouteProvider`; `*View` conforms to `View`; `*Repository` in
///   `Domain/` is a `protocol`; `*RepositoryImpl` in `Data/` is a `struct` /
///   `class`; an `*Action` / `*State` / `*Event` trio should co-exist per
///   presentation folder (soft — a partial set only prints a warning).
///
/// K5 is scoped to `Packages/Features/**` on purpose: the infra packages *define*
/// the base types the conventions point at (`MviViewModel`, `RouteProvider`,
/// SwiftUI's `View`) and are not themselves feature code. No feature packages
/// exist yet, so K5 passes; it is armed for Task 11 / Task 12.
///
/// ### K4 limitation
/// `topLevelDeclarations` reports type / func / typealias / extension nodes, not
/// bare top-level `let` / `var`. Those are additionally covered by the cheap
/// SwiftLint `no_public_in_data` regex in `quality/.swiftlint.yml`.
final class DeclRulesTests: XCTestCase {
    // MARK: K4 — Data layer is internal

    func testK4_DataLayerDeclarationsAreNotPublic() {
        let baseline = Baseline.load()
        var offenders: [String] = []
        for file in packageSourceFiles(matching: "/Data/") {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K4", path: relative) {
                continue
            }
            for decl in SyntaxScanner.topLevelDeclarations(in: tree) {
                guard decl.modifiers.contains("public") || decl.modifiers.contains("open") else { continue }
                offenders.append("\(relative) — \(decl.modifiers.joined(separator: " ")) \(decl.kind) \(decl.name)")
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "K4: declarations on a /Data/ path must be internal:\n" + offenders.joined(separator: "\n")
        )
    }

    // MARK: K5 — naming & conformance conventions (feature code only)

    func testK5_FeatureTypeNamingConventions() {
        var offenders: [String] = []

        for file in featureSourceFiles() {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            let inData = file.path.contains("/Data/")
            let inDomain = file.path.contains("/Domain/")
            let relative = relativePath(of: file)

            for decl in SyntaxScanner.topLevelDeclarations(in: tree) {
                offenders += viewModelOffenders(decl, relative)
                offenders += routeProviderOffenders(decl, relative)
                offenders += viewOffenders(decl, relative)
                offenders += repositoryOffenders(decl, relative, inData: inData, inDomain: inDomain)
            }
        }

        warnOnPartialContractTriads()

        XCTAssertTrue(
            offenders.isEmpty,
            "K5: naming / conformance convention violated:\n" + offenders.joined(separator: "\n")
        )
    }

    /// `*ViewModel` (but not the bare word) must inherit an MVI base class.
    private func viewModelOffenders(_ decl: DeclInfo, _ relative: String) -> [String] {
        guard decl.name != "ViewModel", decl.name.hasSuffix("ViewModel") else { return [] }
        let inheritsBase = decl.inheritedTypeNames.contains {
            $0.hasPrefix("MviViewModel") || $0.hasPrefix("MvvmViewModel")
        }
        return inheritsBase ? [] : ["\(relative) — \(decl.name) must inherit MviViewModel / MvvmViewModel"]
    }

    /// `*RouteProvider` must conform to `RouteProvider`.
    private func routeProviderOffenders(_ decl: DeclInfo, _ relative: String) -> [String] {
        guard decl.name != "RouteProvider", decl.name.hasSuffix("RouteProvider") else { return [] }
        let conforms = decl.inheritedTypeNames.map(rootIdentifier).contains("RouteProvider")
        return conforms ? [] : ["\(relative) — \(decl.name) must conform to RouteProvider"]
    }

    /// `*View` must conform to SwiftUI's `View`.
    private func viewOffenders(_ decl: DeclInfo, _ relative: String) -> [String] {
        guard decl.name != "View", decl.name.hasSuffix("View") else { return [] }
        let conforms = decl.inheritedTypeNames.map(rootIdentifier).contains("View")
        return conforms ? [] : ["\(relative) — \(decl.name) must conform to View"]
    }

    /// `*RepositoryImpl` in `Data/` is a `struct` / `class`; `*Repository` in
    /// `Domain/` is a `protocol`.
    private func repositoryOffenders(
        _ decl: DeclInfo,
        _ relative: String,
        inData: Bool,
        inDomain: Bool
    ) -> [String] {
        let name = decl.name
        if inData, name.hasSuffix("RepositoryImpl") {
            let shaped = ["struct", "class"].contains(decl.kind)
            return shaped ? [] : ["\(relative) — \(name) must be a struct or class in Data/"]
        }
        if inDomain, name != "Repository", name.hasSuffix("Repository") {
            return decl.kind == "protocol" ? [] : ["\(relative) — \(name) must be a protocol in Domain/"]
        }
        return []
    }

    /// Soft check: for each `Presentation/<Screen>/` folder that declares any of
    /// `*Action` / `*State` / `*Event`, print a warning if the set is partial.
    private func warnOnPartialContractTriads() {
        var byFolder: [String: Set<String>] = [:]
        for file in featureSourceFiles() where file.path.contains("/Presentation/") {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            let folder = file.deletingLastPathComponent().path
            for decl in SyntaxScanner.topLevelDeclarations(in: tree) {
                for suffix in ["Action", "State", "Event"] where decl.name.hasSuffix(suffix) && decl.name != suffix {
                    byFolder[folder, default: []].insert(suffix)
                }
            }
        }
        for (folder, present) in byFolder.sorted(by: { $0.key < $1.key }) where present.count < 3 {
            let missing = Set(["Action", "State", "Event"]).subtracting(present).sorted()
            print("warning: K5 — \(relativeString(folder)) has a partial Action/State/Event triad "
                + "(missing: \(missing.joined(separator: ", ")))")
        }
    }

    // MARK: File discovery

    private func packageSourceFiles(matching segment: String) -> [URL] {
        SyntaxScanner.swiftFiles(under: RepoRoot.url(for: "Packages"))
            .filter { $0.path.contains("/Sources/") && $0.path.contains(segment) }
    }

    private func featureSourceFiles() -> [URL] {
        SyntaxScanner.swiftFiles(under: RepoRoot.url(for: "Packages/Features"))
            .filter { $0.path.contains("/Sources/") }
    }

    // MARK: Small helpers

    private func rootIdentifier(_ type: String) -> String {
        type.split { $0 == "<" || $0 == "." || $0 == " " }.first.map(String.init) ?? type
    }

    private func relativePath(of url: URL) -> String {
        relativeString(url.path)
    }

    private func relativeString(_ path: String) -> String {
        path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
    }
}
