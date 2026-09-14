import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Tier A — `ShellTabResolver` (Task 8, Source Spec §4.8): the single place
/// the shell's tab layout is restated.
///
/// `Platform.TabPlacement` is qualified throughout: this file imports both
/// `SwiftUI` (whose iOS 18+ `TabPlacement` collides by name) and `Platform`.
@MainActor
final class ShellTabResolverTests: XCTestCase {
    private struct UnrelatedRoute: AppRoute {}
    private struct UnregisteredPrivateRoute: AppRoute {}

    func testSettingsRootResolvesToItsConfiguredTab() {
        let sut = ShellTabResolver()

        XCTAssertEqual(
            sut.placement(for: AppRoutes.SettingsRoot()),
            Platform.TabPlacement(tab: 2, isTabRoot: true)
        )
    }

    func testAFeaturePrivateRouteHasNoOpinion() {
        let sut = ShellTabResolver()

        XCTAssertNil(sut.placement(for: UnregisteredPrivateRoute()))
    }

    func testAnUnrelatedRouteHasNoOpinion() {
        let sut = ShellTabResolver()

        XCTAssertNil(sut.placement(for: UnrelatedRoute()))
    }
}
