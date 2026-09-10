import Platform
import Scanner
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Tier A — `ShellTabResolver` (Task 8, Source Spec §4.8): the single place
/// the shell's tab layout is restated. Pinned exactly against
/// `Packages/Shell/Sources/Shell/ShellView.swift`'s real, hard-coded layout —
/// tab 0 is a Shell-owned stub with no `AppRoute`, tab 1 is
/// `AppRoutes.ScannerRoot`, tab 2 is `AppRoutes.SettingsRoot` — so a wrong
/// answer here is the only thing that would ever catch the two maps
/// silently diverging.
///
/// `Platform.TabPlacement` is qualified throughout: this file imports both
/// `SwiftUI` (whose iOS 18+ `TabPlacement` collides by name) and `Platform`.
@MainActor
final class ShellTabResolverTests: XCTestCase {
    private struct UnrelatedRoute: AppRoute {}

    func testScannerRootResolvesToTabOneAsItsOwnRoot() {
        let sut = ShellTabResolver()

        XCTAssertEqual(
            sut.placement(for: AppRoutes.ScannerRoot()),
            Platform.TabPlacement(tab: 1, isTabRoot: true)
        )
    }

    func testSettingsRootResolvesToTabTwoAsItsOwnRoot() {
        let sut = ShellTabResolver()

        XCTAssertEqual(
            sut.placement(for: AppRoutes.SettingsRoot()),
            Platform.TabPlacement(tab: 2, isTabRoot: true)
        )
    }

    func testAFeaturePrivateRouteHasNoOpinion() {
        // `ScannerResultRoute` is Scanner's real feature-private child route
        // (never a tab root itself) — the resolver is only ever consulted
        // about `stack[0]`, which by the parent-chain convention every
        // feature's `deepLinks` follows is always that feature's tab root, so
        // `nil` here is correct, not a gap.
        let sut = ShellTabResolver()

        XCTAssertNil(sut.placement(for: ScannerResultRoute(code: "ABC123")))
    }

    func testAnUnrelatedRouteHasNoOpinion() {
        let sut = ShellTabResolver()

        XCTAssertNil(sut.placement(for: UnrelatedRoute()))
    }
}
