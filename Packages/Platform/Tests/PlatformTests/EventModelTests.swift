import XCTest
@testable import Platform

/// Construction / field smoke tests for the event value types and the
/// cross-feature route values, so every public initialiser is exercised.
final class EventModelTests: XCTestCase {
    func testShellTabVisibilityChangedCarriesItsFields() {
        let event = ShellTabVisibilityChanged(tabIndex: 3, isVisible: true)

        XCTAssertEqual(event.tabIndex, 3)
        XCTAssertTrue(event.isVisible)
    }

    func testAppLifecycleChangedCarriesItsState() {
        XCTAssertEqual(AppLifecycleChanged(state: .foreground).state, .foreground)
        XCTAssertEqual(AppLifecycleChanged(state: .background).state, .background)
        XCTAssertEqual(AppLifecycleChanged(state: .inactive).state, .inactive)
    }

    func testUserLoggedOutIsConstructible() {
        _ = UserLoggedOut()
    }

    func testCrossFeatureRouteValuesAreConstructibleAndEquatable() {
        XCTAssertEqual(AppRoutes.SettingsRoot(), AppRoutes.SettingsRoot())
        XCTAssertEqual(AppRoutes.ScannerRoot(), AppRoutes.ScannerRoot())
    }
}
