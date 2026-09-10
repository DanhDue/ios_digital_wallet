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

// MARK: - `DeepLinkRoute` construction (Task 4)

/// Boundary-value / equivalence-partition contract for ``DeepLinkRoute`` and
/// the ``RouteProvider/deepLinks`` seam it plugs into (Source Spec §4.3,
/// §4.4). Nothing resolves through this yet — Task 5's router is the first
/// reader of `deepLinks` — so these tests pin construction and the `build`
/// contract in isolation.
extension RouteProviderTests {
    // MARK: Pattern forms

    func testDeepLinkRouteInitParsesLeadingSlashPatternString() {
        let route = DeepLinkRoute("/settings") { _ in [] }

        XCTAssertEqual(route.pattern, DeepLinkPattern("/settings"))
    }

    /// Mirrors Task 3: the leading `/` is optional, so a route authored
    /// without it must parse to the same pattern as one authored with it.
    func testDeepLinkRouteInitWithoutLeadingSlashMatchesWithLeadingSlashForm() {
        let withSlash = DeepLinkRoute("/settings") { _ in [] }
        let withoutSlash = DeepLinkRoute("settings") { _ in [] }

        XCTAssertEqual(withSlash.pattern, withoutSlash.pattern)
    }

    /// Adversarial: a zero-segment (root) pattern is a legal route shape,
    /// not a special case the initializer needs to reject.
    func testDeepLinkRouteInitWithRootPatternHasZeroSegments() {
        let route = DeepLinkRoute("/") { _ in [] }

        XCTAssertEqual(route.pattern.segments, [])
    }

    func testDeepLinkRouteInitParsesParameterSegment() {
        let route = DeepLinkRoute("/tx/:id") { _ in [] }

        XCTAssertEqual(route.pattern.segments, [.literal("tx"), .parameter("id")])
    }

    // MARK: `requiresAuth` defaulting (DoD: "defaulting to `false`")

    func testDeepLinkRouteRequiresAuthDefaultsToFalseWhenOmitted() {
        let route = DeepLinkRoute("/settings") { _ in [] }

        XCTAssertFalse(route.requiresAuth)
    }

    func testDeepLinkRouteRequiresAuthIsTrueWhenExplicitlyRequested() {
        let route = DeepLinkRoute("/wallet/send", requiresAuth: true) { _ in [] }

        XCTAssertTrue(route.requiresAuth)
    }

    /// Equivalence partition distinct from the default: explicitly passing
    /// `false` must behave identically to omitting the argument.
    func testDeepLinkRouteRequiresAuthIsFalseWhenExplicitlyDeclinedByCaller() {
        let route = DeepLinkRoute("/settings", requiresAuth: false) { _ in [] }

        XCTAssertFalse(route.requiresAuth)
    }

    // MARK: `build` contract — array result, declaration order (DoD property 1)

    @MainActor
    func testBuildReturningEmptyArrayYieldsNoRoutes() {
        let route = DeepLinkRoute("/settings") { _ in [] }

        let result = route.build(DeepLinkParams())

        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testBuildReturningSingleRouteYieldsExactlyThatOneRoute() {
        let route = DeepLinkRoute("/settings") { _ in [RouteA()] }

        let result = route.build(DeepLinkParams())

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] is RouteA)
    }

    /// The must-pin property: `build` returns the parent-to-child stack, and
    /// the array's order is exactly the declaration order — never reordered,
    /// deduplicated, or reversed. Checked by unwrapping each element's typed
    /// payload in sequence, not merely by `count` or `contains`.
    @MainActor
    func testBuildReturningMultipleRoutesPreservesExactDeclarationOrder() {
        let route = DeepLinkRoute("/wallet/send/confirm") { _ in
            [NumberedRoute(value: 1), NumberedRoute(value: 2), NumberedRoute(value: 3)]
        }

        let result = route.build(DeepLinkParams())

        XCTAssertEqual(result.compactMap { ($0 as? NumberedRoute)?.value }, [1, 2, 3])
    }

    /// The `build` closure must receive the exact params instance passed to
    /// it, unchanged — proven by round-tripping a value through it rather
    /// than asserting on some incidental default.
    @MainActor
    func testBuildReceivesTheExactParamsItWasInvokedWith() {
        let route = DeepLinkRoute("/tx/:id") { params in
            [NumberedRoute(value: Int(params["id"] ?? "") ?? -1)]
        }

        let result = route.build(DeepLinkParams(["id": "42"]))

        XCTAssertEqual((result.first as? NumberedRoute)?.value, 42)
    }

    /// Adversarial: a `build` closure that captures mutable state is not a
    /// single-shot callback — invoking it twice must run the closure twice,
    /// each time reflecting the state as it stood at that call.
    @MainActor
    func testBuildClosureCapturingMutableStateReflectsEachInvocation() {
        var callCount = 0
        let route = DeepLinkRoute("/settings") { _ in
            callCount += 1
            return [NumberedRoute(value: callCount)]
        }

        let first = route.build(DeepLinkParams())
        let second = route.build(DeepLinkParams())

        XCTAssertEqual((first.first as? NumberedRoute)?.value, 1)
        XCTAssertEqual((second.first as? NumberedRoute)?.value, 2)
        XCTAssertEqual(callCount, 2)
    }
}

// MARK: - `RouteProvider.deepLinks` default (Task 4)

extension RouteProviderTests {
    /// A provider that never overrides `deepLinks` — the shape of every
    /// `RouteProvider` shipped before this task (`SettingsRouteProvider`,
    /// `ScannerRouteProvider`) — must still satisfy the protocol and must
    /// resolve to the empty array via the default extension, not a crash or
    /// a compile error.
    @MainActor
    func testProviderNotOverridingDeepLinksDefaultsToEmptyArray() {
        let provider = MockRouteProvider<RouteA>()

        XCTAssertEqual(provider.deepLinks.count, 0)
    }

    /// A provider that *does* override `deepLinks` must return exactly the
    /// routes it declared, in the order it declared them — the other half of
    /// the conformance partition (overrides vs. relies-on-default).
    @MainActor
    func testProviderOverridingDeepLinksReturnsDeclaredRoutesInDeclarationOrder() {
        let provider = DeepLinkDeclaringRouteProvider()

        let patterns = provider.deepLinks.map(\.pattern)

        XCTAssertEqual(patterns, [DeepLinkPattern("/settings"), DeepLinkPattern("/wallet/send")])
    }
}

/// A `RouteProvider` that declares two deep links, used to pin the
/// "overrides `deepLinks`" partition of the conformance contract. Declared
/// privately in this file, mirroring `ShellTests/FeatureBlindRenderTests`'s
/// `UnregisteredRouteProvider` — a test-only conformance scoped to the one
/// suite that needs it.
private final class DeepLinkDeclaringRouteProvider: RouteProvider {
    func canHandle(_: any AppRoute) -> Bool {
        false
    }

    func destination(for _: any AppRoute) -> AnyView {
        AnyView(EmptyView())
    }

    @MainActor
    var deepLinks: [DeepLinkRoute] {
        [
            DeepLinkRoute("/settings") { _ in [AppRoutes.SettingsRoot()] },
            DeepLinkRoute("/wallet/send") { _ in [RouteA(), RouteB()] },
        ]
    }
}
