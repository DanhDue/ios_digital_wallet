import XCTest
@testable import Platform

/// Unit-level equality / hashing / round-trip contract for ``AnyAppRoute``,
/// the `Hashable` box `AppRouter.navigate(to:inTab:)` uses to erase route
/// types before they reach `SwiftUI.NavigationPath` (Source Spec §4.7).
///
/// The one invariant every other test in the suite depends on: two distinct
/// route types with identical stored values must never compare equal —
/// otherwise `NavigationPath` deduplication / back navigation misbehaves.
final class AnyAppRouteTests: XCTestCase {
    // MARK: Equality / hashing — same type

    func testSameTypeSameEmptyValueAreEqualAndHashEqual() {
        let lhs = AnyAppRoute(RouteA())
        let rhs = AnyAppRoute(RouteA())

        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.hashValue, rhs.hashValue)
    }

    func testSameTypeSameNonTrivialValueAreEqualAndHashEqual() {
        let lhs = AnyAppRoute(NumberedRoute(value: 7))
        let rhs = AnyAppRoute(NumberedRoute(value: 7))

        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.hashValue, rhs.hashValue)
    }

    func testSameTypeDifferentValueAreNotEqual() {
        let lhs = AnyAppRoute(NumberedRoute(value: 1))
        let rhs = AnyAppRoute(NumberedRoute(value: 2))

        XCTAssertNotEqual(lhs, rhs)
    }

    // MARK: Equality — distinct types (critical invariant)

    func testDistinctTypesWithIdenticalStoredValuesAreNotEqual() {
        let lhs = AnyAppRoute(NumberedRoute(value: 42))
        let rhs = AnyAppRoute(AltNumberedRoute(value: 42))

        XCTAssertNotEqual(lhs, rhs, "different route types must never compare equal, even with identical payloads")
    }

    func testDistinctZeroPropertyTypesAreNotEqual() {
        let lhs = AnyAppRoute(RouteA())
        let rhs = AnyAppRoute(RouteB())

        XCTAssertNotEqual(lhs, rhs, "a route with no stored properties is still distinguished by its concrete type")
    }

    // MARK: wrapped round-trip

    func testWrappedRoundTripsTheOriginalValueExactly() throws {
        let boxed = AnyAppRoute(NumberedRoute(value: 9))

        let recovered = try XCTUnwrap(boxed.wrapped as? NumberedRoute)

        XCTAssertEqual(recovered, NumberedRoute(value: 9))
    }

    func testWrappedPreservesTheOriginalDynamicTypeForAZeroPropertyRoute() {
        let boxed = AnyAppRoute(RouteA())

        XCTAssertTrue(boxed.wrapped is RouteA)
        XCTAssertFalse(boxed.wrapped is RouteB)
    }

    func testWrappedRoundTripsAnAppRoutesValue() {
        let boxed = AnyAppRoute(AppRoutes.SettingsRoot())

        XCTAssertTrue(boxed.wrapped is AppRoutes.SettingsRoot)
        XCTAssertEqual(boxed.wrapped as? AppRoutes.SettingsRoot, AppRoutes.SettingsRoot())
    }
}
