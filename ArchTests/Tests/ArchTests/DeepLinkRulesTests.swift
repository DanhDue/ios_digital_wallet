import ArchTestSupport
import Foundation
import XCTest

/// **K10** — deep-link governance rules (Source Spec §7): the repo's stated
/// philosophy is *enforce structurally, do not rely on discipline*, applied
/// to `DeepLinkRoute` declarations, which are scattered across every feature
/// package and therefore drift without a structural check.
///
/// - **K10.1** — no two `DeepLinkRoute` declarations across the repo share a
///   pattern string (duplicates silently shadow each other at resolution
///   time — Task 5's first-match-wins contract is only safe because this
///   holds).
/// - **K10.2** — every route type declared in
///   `Platform/Navigation/AppRoutes.swift` is referenced by at least one
///   `DeepLinkRoute.build` body — a cross-feature entry point that cannot be
///   addressed by URL is exactly the asymmetry criterion 2.1 forbids.
/// - **K10.3** — pattern segments are well-formed: literal `^[a-z0-9-]+$`,
///   parameter `^:[a-z][a-zA-Z0-9]*$`.
/// - **K10.4** — the app entry point wires `.onOpenURL` to
///   `deepLinkRouter.open` — a crude source-text pin standing in for the
///   behavioural coverage Task 9 showed only a UI test can provide.
/// - **K10.5** — no single pattern declares the same parameter name twice
///   (`DeepLinkPattern.match` resolves a repeat last-wins, silently dropping
///   a captured value — Task 3's Ruling 5).
/// - **K10.6** — every `DeepLinkRoute(...)` call's first argument must be a
///   static string literal. Without this, an interpolated pattern, a `let`
///   variable, or a helper-function parameter passed as the pattern makes
///   the call vanish from `deepLinkRouteCalls(in:)` entirely — K10.1,
///   K10.3 and K10.5 would go blind to it *simultaneously*, in the
///   dangerous direction (a pattern nobody is checking, not a false
///   alarm). K10.6 turns that silent disappearance into a loud, located
///   failure instead.
///
/// Mechanism: K10.1/K10.2/K10.3/K10.5 all walk
/// `SyntaxScanner.deepLinkRouteCalls(in:)` — one AST pass over every
/// `DeepLinkRoute(...)` call site under `Features/*/Sources`,
/// `Packages/*/Sources` and `App/Sources` — rather than four independent
/// re-derivations of "what is a declared route". K10.2 additionally shares
/// `AppRouteScanning.appRouteTypeNames(in:)` with K9's "what is a route
/// declared in `AppRoutes`" traversal. K10.4 is deliberately a source-text
/// pin, not an AST rule — see its test for why. K10.6 walks the sibling
/// `SyntaxScanner.unresolvedDeepLinkRouteCalls(in:)` — the same
/// `DeepLinkRoute` call sites, but the ones the other four couldn't read a
/// pattern from — including a fully-qualified `Platform.DeepLinkRoute(...)`
/// call, which `deepLinkRouteCalls(in:)`'s callee-name check would
/// otherwise drop even earlier than the literal check.
final class DeepLinkRulesTests: XCTestCase {
    // MARK: K10.1 — no two DeepLinkRoute declarations share a pattern

    func testK10_1_NoTwoDeepLinkRoutesShareAPatternString() {
        let baseline = Baseline.load()
        var occurrences: [String: [String]] = [:]

        for file in repoSourceFiles() {
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K10.1", path: relative) {
                continue
            }
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for call in SyntaxScanner.deepLinkRouteCalls(in: tree) {
                occurrences[call.pattern, default: []].append(relative)
            }
        }

        var offenders: [String] = []
        for (pattern, files) in occurrences.sorted(by: { $0.key < $1.key }) where files.count > 1 {
            offenders.append(
                "K10.1: pattern `\(pattern)` is declared more than once — \(files.sorted().joined(separator: ", "))"
            )
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: K10.2 — every AppRoutes member is reachable by a DeepLinkRoute.build body

    func testK10_2_EveryAppRoutesMemberIsReferencedByADeepLinkBuildBody() {
        let baseline = Baseline.load()
        let appRoutesFile = RepoRoot.url(for: "Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift")
        let relativeAppRoutesFile = relativePath(of: appRoutesFile)
        let declaredRouteNames = AppRouteScanning.appRouteTypeNames(in: [appRoutesFile])

        var referencedIdentifiers: Set<String> = []
        for file in repoSourceFiles() {
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for call in SyntaxScanner.deepLinkRouteCalls(in: tree) {
                referencedIdentifiers.formUnion(call.referencedIdentifiers)
            }
        }

        var offenders: [String] = []
        for routeName in declaredRouteNames.sorted() {
            if baseline.isBaselined(rule: "K10.2", path: "\(relativeAppRoutesFile)#\(routeName)") {
                continue
            }
            if !referencedIdentifiers.contains(routeName) {
                offenders.append(
                    "K10.2: \(relativeAppRoutesFile) declares AppRoutes.\(routeName), but no "
                        + "DeepLinkRoute.build body references it"
                )
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: K10.3 — pattern segments are well-formed

    func testK10_3_PatternSegmentsAreWellFormed() {
        let baseline = Baseline.load()
        var offenders: [String] = []

        for file in repoSourceFiles() {
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K10.3", path: relative) {
                continue
            }
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for call in SyntaxScanner.deepLinkRouteCalls(in: tree) {
                for rawSegment in patternSegments(call.pattern) {
                    let segment = String(rawSegment)
                    if segment.hasPrefix(":") {
                        guard matches(segment, pattern: #"^:[a-z][a-zA-Z0-9]*$"#) else {
                            offenders.append(
                                "K10.3: \(relative) — pattern `\(call.pattern)` has malformed parameter "
                                    + "segment `\(segment)` (expected ^:[a-z][a-zA-Z0-9]*$)"
                            )
                            continue
                        }
                    } else {
                        guard matches(segment, pattern: #"^[a-z0-9-]+$"#) else {
                            offenders.append(
                                "K10.3: \(relative) — pattern `\(call.pattern)` has malformed literal "
                                    + "segment `\(segment)` (expected ^[a-z0-9-]+$)"
                            )
                            continue
                        }
                    }
                }
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: K10.4 — the app entry point wires .onOpenURL to deepLinkRouter.open

    /// A source-text pin, not an AST rule (deliberately — see the type doc).
    /// `.onOpenURL` is the one link in the deep-link chain with no
    /// behavioural coverage (Task 9 showed only a UI test catches its
    /// deletion at runtime); this is a cheap regression net, not a
    /// substitute for that UI test.
    func testK10_4_AppEntryPointWiresOnOpenURLToDeepLinkRouterOpen() throws {
        let file = try appEntryPointFile()
        let relative = relativePath(of: file)
        let source = try String(contentsOf: file, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".onOpenURL"),
            "K10.4: \(relative) must call `.onOpenURL` to receive incoming deep links"
        )
        XCTAssertTrue(
            source.contains("deepLinkRouter.open"),
            "K10.4: \(relative) must call `deepLinkRouter.open` from its `.onOpenURL` handler"
        )
    }

    // MARK: K10.5 — no pattern declares the same parameter name twice

    func testK10_5_NoPatternRepeatsAParameterName() {
        let baseline = Baseline.load()
        var offenders: [String] = []

        for file in repoSourceFiles() {
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K10.5", path: relative) {
                continue
            }
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for call in SyntaxScanner.deepLinkRouteCalls(in: tree) {
                var seen: Set<String> = []
                var duplicates: Set<String> = []
                for rawSegment in patternSegments(call.pattern) where rawSegment.hasPrefix(":") {
                    let name = String(rawSegment.dropFirst())
                    if !seen.insert(name).inserted {
                        duplicates.insert(name)
                    }
                }
                for name in duplicates.sorted() {
                    offenders.append(
                        "K10.5: \(relative) — pattern `\(call.pattern)` declares parameter `:\(name)` "
                            + "more than once"
                    )
                }
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: K10.6 — every DeepLinkRoute's pattern must be a static string literal

    /// Closes the bypass that would otherwise let K10.1 / K10.3 / K10.5 go
    /// blind: `SyntaxScanner.deepLinkRouteCalls(in:)` only reports a call
    /// once it can read its pattern as a plain string literal, so an
    /// interpolated pattern, a `let`-bound pattern, or a parameter passed
    /// through as the pattern would otherwise vanish from every rule that
    /// walks it — not fail, just disappear. This rule walks the sibling
    /// `unresolvedDeepLinkRouteCalls(in:)` (the same call sites, minus a
    /// readable pattern) and fails loudly instead, naming the file and line.
    func testK10_6_EveryDeepLinkRoutePatternIsAStaticStringLiteral() {
        let baseline = Baseline.load()
        var offenders: [String] = []

        for file in repoSourceFiles() {
            let relative = relativePath(of: file)
            if baseline.isBaselined(rule: "K10.6", path: relative) {
                continue
            }
            guard let tree = try? SyntaxScanner.parse(fileAt: file) else { continue }
            for unresolved in SyntaxScanner.unresolvedDeepLinkRouteCalls(in: tree) {
                offenders.append(
                    "K10.6: \(relative):\(unresolved.line) — DeepLinkRoute(...)'s first argument must be a "
                        + "static string literal, not an interpolated / computed value"
                )
            }
        }
        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    // MARK: Helpers

    /// Every `.swift` file under `Features/*/Sources`, `Packages/*/Sources`
    /// and `App/Sources` — the whole repo's *production* source, which is
    /// where a `DeepLinkRoute(...)` call site can legally appear. Tests are
    /// excluded on purpose: `Packages/Platform/Tests/**` constructs
    /// `DeepLinkRoute` values with the same demo patterns for fixture
    /// purposes, which would otherwise read as K10.1 duplicates of
    /// production declarations.
    private func repoSourceFiles() -> [URL] {
        let roots = ["Features", "Packages", "App"]
        return roots
            .flatMap { root in SyntaxScanner.swiftFiles(under: RepoRoot.url(for: root)) }
            .filter { $0.path.contains("/Sources/") }
            .sorted { $0.path < $1.path }
    }

    /// Splits a raw pattern string into its `/`-delimited segments exactly as
    /// `DeepLinkPattern.init` does (Task 2, Source Spec §4.2): a leading `/`
    /// is optional, and consecutive/trailing `/` never produce an empty
    /// segment. ArchTests does not depend on `Platform`, so this re-derives
    /// that one split rather than importing it — K10.3 and K10.5 both call
    /// this instead of each re-deriving the split themselves.
    private func patternSegments(_ pattern: String) -> [Substring] {
        pattern.split(separator: "/", omittingEmptySubsequences: true)
    }

    private func matches(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    /// Locates `App/Sources/<AppName>App.swift` by name convention
    /// (`*App.swift`) rather than hardcoding `iOSDigitalWalletApp.swift`, so
    /// K10.4 survives an app rename.
    private func appEntryPointFile() throws -> URL {
        let directory = RepoRoot.url(for: "App/Sources")
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let candidates = entries
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent.hasSuffix("App.swift") }
            .sorted { $0.path < $1.path }
        guard let entryPoint = candidates.first else {
            XCTFail("K10.4: no App/Sources/*App.swift entry point found")
            throw CocoaError(.fileNoSuchFile)
        }
        return entryPoint
    }

    private func relativePath(of url: URL) -> String {
        url.path.replacingOccurrences(of: RepoRoot.path + "/", with: "")
    }
}
