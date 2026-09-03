import SwiftUI
import XCTest
@testable import Platform

final class RouteProviderTests: XCTestCase {
    func testMockProviderCanHandleOnlyItsOwnRouteType() {
        let provider = MockRouteProvider<RouteA>()

        XCTAssertTrue(provider.canHandle(RouteA()))
        XCTAssertFalse(provider.canHandle(RouteB()))
        XCTAssertFalse(provider.canHandle(AppRoutes.SettingsRoot()))
    }

    func testDestinationForRecordsTheCallAndReturnsAView() {
        let provider = MockRouteProvider<RouteA>()

        _ = provider.destination(for: RouteA())

        XCTAssertEqual(provider.destinationCallCount, 1)
        XCTAssertTrue(provider.lastRoute is RouteA)
    }

    func testAppRoutesValuesAreDistinctRouteTypes() {
        let settings: any AppRoute = AppRoutes.SettingsRoot()

        XCTAssertTrue(settings is AppRoutes.SettingsRoot)
        XCTAssertFalse(settings is AppRoutes.ScannerRoot)
        XCTAssertEqual(AppRoutes.SettingsRoot(), AppRoutes.SettingsRoot())
    }
}
