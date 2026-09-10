import Core
import SwiftUI
import XCTest
@testable import Platform

/// Boundary-value / equivalence-partition contract for ``DeepLinkRouter``,
/// ``DeepLinkGuard``, and ``TabResolver`` (Source Spec §4.5, §4.6): the
/// engine that resolves a `URL` to a route stack, gates it through an
/// optional guard, places it through an optional tab resolver, drives
/// `AppRouter`, and replays a single pending link.
///
/// Split across `DeepLinkRouterTests` (Resolution, Navigation),
/// `DeepLinkRouterGatingTests` (Gating, Redirect re-entrancy), and
/// `DeepLinkRouterPendingTests` (Pending, State-mutation invariant,
/// Async/ordering) — one `XCTestCase` per BDD category group, to stay under
/// this repo's `file_length` / `type_body_length` SwiftLint ceilings. All
/// three share `deepLinkTestURL(_:)` and `expectedDeepLinkPath(_:)` from
/// `TestSupport.swift`.
@MainActor
final class DeepLinkRouterTests: XCTestCase {
    // MARK: - Resolution

    func testOpenWithNoProvidersRegisteredYieldsUnmatched() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(router.selectedTab, selectedTabBefore, "no provider means nothing could possibly have moved")
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    func testOpenWithOneProviderDeclaringNoPatternsYieldsUnmatched() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(router.selectedTab, selectedTabBefore, "an empty deepLinks table can't have moved anything")
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    /// The carried Task-4 note: `deepLinks` has only ever been exercised on
    /// concrete provider types. `register(_:)` takes `any RouteProvider`, so
    /// this test registers through an existential-typed binding — and, in
    /// the same scenario, pins first-match-wins across two providers
    /// registered in order: provider 1's `/settings` route must win even
    /// though provider 2 declares an identical pattern.
    func testOpenFirstMatchWinsAcrossTwoProvidersRegisteredThroughExistentialBinding() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)

        let first: any RouteProvider = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ])
        let second: any RouteProvider = FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteB()] },
        ])
        deepLinkRouter.register(first)
        deepLinkRouter.register(second)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([RouteA()]),
            "provider 1's route must win, not provider 2's"
        )
    }

    func testOpenWithNoPatternMatchingTheLinkYieldsUnmatched() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://wallet/send"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(router.tabPaths[0].count, 0)
    }

    func testOpenWhenBuildReturnsEmptyArrayYieldsUnmatchedAndNeverConsultsTheGuard() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard()
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(fakeGuard.callCount, 0, "an empty build() result must never reach the guard")
    }

    /// `DeepLink.init?(url:)`'s own `nil` partition (Task 2) requires a
    /// string that fails at `URL(string:)` — e.g. `"app://[bad_host/path"`
    /// — which means no `URL` value ever exists to pass to `open(_:)` in the
    /// first place; exhaustive probing found no `URL(string:)`-constructible
    /// value on this Foundation runtime for which `URLComponents(url:
    /// resolvingAgainstBaseURL: false)` still fails. That exact partition is
    /// therefore already exhaustively pinned at its true boundary by
    /// `DeepLinkTests` (Task 2). This test instead pins the coarser
    /// guarantee this layer actually owns: a syntactically valid but
    /// entirely unregistered URL is ordinary input, never a crash, and
    /// yields `.unmatched` like any other non-match.
    func testOpenWithSyntacticallyValidButWhollyUnregisteredURLYieldsUnmatched() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("ftp://nowhere/does-not-exist"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(router.selectedTab, selectedTabBefore, "junk input must never move anything")
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    // MARK: - Navigation

    func testOpenAllowedWithNoResolverUsesCurrentTabPopsToRootAndPushesInDeclarationOrder() {
        let router = AppRouter(tabCount: 3, initialTab: 1)
        router.navigate(to: RouteA(), inTab: 1) // pre-existing stack popToRoot must wipe
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send/confirm") { _ in
                [NumberedRoute(value: 1), NumberedRoute(value: 2), NumberedRoute(value: 3)]
            },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://wallet/send/confirm"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 1, "no resolver ⇒ stays on the currently selected tab")
        XCTAssertEqual(
            router.tabPaths[1],
            expectedDeepLinkPath([NumberedRoute(value: 1), NumberedRoute(value: 2), NumberedRoute(value: 3)]),
            "must be popped to root first, then pushed in exactly declaration order"
        )
        XCTAssertEqual(router.tabPaths[0].count, 0)
        XCTAssertEqual(router.tabPaths[2].count, 0)
    }

    func testOpenAllowedWithResolverNonRootPlacementSwitchesTabAndPushesFullStack() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 2, isTabRoot: false) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/tx/:id") { _ in [RouteA(), RouteB()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://tx/42"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 2)
        XCTAssertEqual(
            router.tabPaths[2],
            expectedDeepLinkPath([RouteA(), RouteB()]),
            "non-root ⇒ the full stack is pushed"
        )
    }

    /// `isTabRoot` must drop **exactly** the first element and no more.
    func testIsTabRootDropsExactlyTheFirstElementAndNoMore() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 1, isTabRoot: true) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/scanner/result/:code") { _ in
                [RouteA(), NumberedRoute(value: 1), NumberedRoute(value: 2)]
            },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(
            router.tabPaths[1],
            expectedDeepLinkPath([NumberedRoute(value: 1), NumberedRoute(value: 2)]),
            "only the first (root) element is dropped; the rest of the stack survives intact"
        )
    }

    /// Boundary: a single-element stack that *is* the tab's root pushes
    /// nothing at all, yet the tab still switches and still reports
    /// `.opened` — "nothing left to push" is not a failure.
    func testSingleElementStackThatIsTheTabRootPushesNothingButStillSwitchesAndSucceeds() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 1, isTabRoot: true) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened, "no duplicated screen: /settings must not push SettingsRoot a second time")
        XCTAssertEqual(router.selectedTab, 1)
        XCTAssertEqual(router.tabPaths[1].count, 0)
    }

    func testResolverReturningNilForThisRouteUsesCurrentTab() {
        let router = AppRouter(tabCount: 2, initialTab: 1)
        let resolver = FakeTabResolver { _ in nil }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 1, "resolver had no opinion ⇒ current tab")
        XCTAssertEqual(resolver.callCount, 1, "the resolver must still be consulted even when it answers nil")
    }

    func testResolverTabIndexZeroBoundaryIsHonoured() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 0, isTabRoot: false) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 0)
        XCTAssertEqual(router.tabPaths[0].count, 1)
    }

    func testResolverLastValidTabIndexBoundaryIsHonoured() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 2, isTabRoot: false) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 2)
        XCTAssertEqual(router.tabPaths[2].count, 1)
    }

    /// The corrected algorithm: an out-of-range tab must fall back to
    /// `selectedTab`, not pass through — `AppRouter`'s mutators silently
    /// no-op on a bad index, so passing one through would report `.opened`
    /// while nothing moved. The bad placement must also be logged exactly
    /// once, and the link must still genuinely land somewhere (`.opened`
    /// stays honest).
    func testOutOfRangeTabFallsBackToSelectedTabStillNavigatesAndLogsOnce() {
        let router = AppRouter(tabCount: 2, initialTab: 1)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 99, isTabRoot: false) }
        let logger = FakeLogger()
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver, logger: logger)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened, ".opened must mean something actually moved, never a false success")
        XCTAssertEqual(router.selectedTab, 1, "falls back to the tab that was selected before the bad placement")
        XCTAssertEqual(
            router.tabPaths[1],
            expectedDeepLinkPath([RouteA()]),
            "the stack must still land, on the fallback tab"
        )
        XCTAssertEqual(logger.errorCount, 1, "the bad placement is logged exactly once")
    }

    /// Fix-round-1 Finding 1: `isTabRoot` is a claim about the tab the
    /// resolver named. When that tab is rejected as out-of-range and the
    /// router falls back to `selectedTab`, the claim is rejected with it —
    /// the fallback tab's root was never asserted to be this stack's first
    /// route, so nothing may be dropped. Regressing to an unconditional
    /// `removeFirst()` would silently discard `WalletRoot` even though tab 0
    /// is not showing Wallet.
    func testOutOfRangeTabWithIsTabRootTruePushesTheFullStackOntoTheFallbackTabInOrder() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 99, isTabRoot: true) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/tx/:id") { _ in [NumberedRoute(value: 1), NumberedRoute(value: 2)] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://wallet/tx/42"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 0, "falls back to the tab that was selected before the bad placement")
        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([NumberedRoute(value: 1), NumberedRoute(value: 2)]),
            "the rejected placement's isTabRoot claim must not drop anything from the fallback tab's stack"
        )
    }

    /// Regression guard for the Finding-1 fix: an **in-range** placement's
    /// `isTabRoot` claim must keep working exactly as before — only a
    /// rejected placement's claim is voided, never a validated one.
    func testInRangeTabWithIsTabRootTrueStillDropsExactlyTheFirstElement() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 1, isTabRoot: true) }
        let deepLinkRouter = DeepLinkRouter(router: router, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings/lang") { _ in [RouteA(), NumberedRoute(value: 1)] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings/lang"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.selectedTab, 1)
        XCTAssertEqual(
            router.tabPaths[1],
            expectedDeepLinkPath([NumberedRoute(value: 1)]),
            "a validated placement's isTabRoot claim must still drop exactly the first element"
        )
    }

    /// Fix-round-1 Finding 2: the fallback target (`router.selectedTab`)
    /// must itself be validated. `AppRouter.init` does not clamp
    /// `initialTab`, so a degenerate configuration can start with an
    /// out-of-range `selectedTab`. Proceeding anyway would call
    /// `switchTab`/`popToRoot`/`navigate` with a bad index, each a silent
    /// no-op, and still report `.opened` — a false success. No new
    /// `DeepLinkOutcome` case is introduced; this reuses `.denied`.
    func testAllowedLinkWithOutOfRangeSelectedTabAndNoResolverIsDeniedNotFalselyOpened() {
        let router = AppRouter(tabCount: 3, initialTab: 7)
        let logger = FakeLogger()
        let deepLinkRouter = DeepLinkRouter(router: router, logger: logger)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .denied, "no usable tab exists; .opened would be a false success")
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
        XCTAssertEqual(logger.errorCount, 1, "the degenerate configuration is logged exactly once")
    }

    /// Same defect, `tabCount: 0` boundary: `AppRouter` explicitly supports
    /// zero tabs, so `router.tabPaths.indices` is empty and `selectedTab`
    /// can never be usable.
    func testAllowedLinkWithZeroTabsIsDeniedNotFalselyOpened() {
        let router = AppRouter(tabCount: 0, initialTab: 0)
        let logger = FakeLogger()
        let deepLinkRouter = DeepLinkRouter(router: router, logger: logger)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .denied)
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
        XCTAssertEqual(logger.errorCount, 1, "logged exactly once")
    }
}
