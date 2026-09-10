import Core
import SwiftUI
import XCTest
@testable import Platform

/// `DeepLinkRouter` pending-link storage/replay, the state-mutation
/// invariant on every failure path, and sequential open()/drainPending()
/// ordering. See `DeepLinkRouterTests` for the split rationale and the
/// shared `deepLinkTestURL(_:)` / `expectedDeepLinkPath(_:)` helpers.
@MainActor
final class DeepLinkRouterPendingTests: XCTestCase {
    // MARK: - Pending

    func testDrainPendingWithEmptyStoreIsANoOp() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard()
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        deepLinkRouter.drainPending()

        XCTAssertEqual(fakeGuard.callCount, 0)
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    func testDrainPendingReplaysToTheCorrectTabAndStackOnceTheGuardAllows() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        let resolver = FakeTabResolver { _ in Platform.TabPlacement(tab: 1, isTabRoot: false) }
        var allow = false
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            if stack.first is RouteB {
                return .allow // the redirect target is always reachable
            }
            return allow ? .allow : .redirect(to: [RouteB()], retainPending: true)
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard, tabResolver: resolver)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/scanner/result/:code") { _ in [NumberedRoute(value: 7)] },
        ]))
        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC")), .pendingGuard)

        allow = true
        deepLinkRouter.drainPending()

        XCTAssertEqual(router.selectedTab, 1)
        XCTAssertEqual(
            router.tabPaths[1],
            expectedDeepLinkPath([NumberedRoute(value: 7)]),
            "drainPending must replay the ORIGINAL matched stack, not the redirect target"
        )
    }

    func testASecondOpenReplacesTheStoredPendingLink() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        var allow = false
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            if allow {
                return .allow
            }
            // Never redirect the redirect target itself in this scenario.
            if stack.first is RouteB {
                return .allow
            }
            return .redirect(to: [RouteB()], retainPending: true)
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [NumberedRoute(value: 1)] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 2)] },
        ]))
        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://wallet/send")), .pendingGuard)
        XCTAssertEqual(
            deepLinkRouter.open(deepLinkTestURL("app://settings")),
            .pendingGuard,
            "second link also redirects"
        )

        allow = true
        deepLinkRouter.drainPending()

        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([NumberedRoute(value: 2)]),
            "the second (settings) link must have replaced the first (wallet/send) as the pending entry"
        )
    }

    func testPendingIsClearedWhenADifferentLinkSucceedsDirectly() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        var mode = 0 // 0: redirect+retain, 1: allow
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            if stack.first is RouteB {
                return .allow // redirect target always allowed
            }
            return mode == 0 ? .redirect(to: [RouteB()], retainPending: true) : .allow
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [RouteA()] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 9)] },
        ]))
        XCTAssertEqual(
            deepLinkRouter.open(deepLinkTestURL("app://wallet/send")),
            .pendingGuard,
            "pending now holds wallet/send"
        )

        mode = 1
        XCTAssertEqual(
            deepLinkRouter.open(deepLinkTestURL("app://settings")),
            .opened,
            "an unrelated link opens directly"
        )

        let callCountAfterSuccess = fakeGuard.callCount
        deepLinkRouter.drainPending()
        XCTAssertEqual(
            fakeGuard.callCount,
            callCountAfterSuccess,
            "a direct .allow must have cleared the old pending link"
        )
    }

    func testPendingIsClearedWhenARedirectDeclinesToRetainAfterAPriorPendingWasStored() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        var retain = true
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            if stack.first is RouteB {
                return .allow
            }
            return .redirect(to: [RouteB()], retainPending: retain)
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [RouteA()] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 3)] },
        ]))
        XCTAssertEqual(
            deepLinkRouter.open(deepLinkTestURL("app://wallet/send")),
            .pendingGuard,
            "pending now holds wallet/send"
        )

        retain = false
        XCTAssertEqual(
            deepLinkRouter.open(deepLinkTestURL("app://settings")),
            .pendingGuard,
            "redirects again, but retains nothing"
        )

        let callCountBeforeDrain = fakeGuard.callCount
        deepLinkRouter.drainPending()
        XCTAssertEqual(
            fakeGuard.callCount,
            callCountBeforeDrain,
            "retainPending: false must have cleared the prior pending link too"
        )
    }

    // MARK: - State-mutation invariant

    // Every failure path — `.unmatched`, `.denied`, and a redirect whose
    // own target is not `.allow` (so nothing ends up pending either) —
    // must leave `AppRouter` byte-for-byte unchanged.

    func testUnmatchedLeavesRouterStateCompletelyUnchanged() {
        let router = AppRouter(tabCount: 3, initialTab: 1)
        router.navigate(to: RouteA(), inTab: 1)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://no-such-route"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    func testDeniedLeavesRouterStateCompletelyUnchanged() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        let fakeGuard = FakeDeepLinkGuard { _, _ in .deny }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteB()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .denied)
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore)
    }

    func testRedirectThatStoresNothingBecauseItsOwnTargetIsDeniedLeavesRouterStateCompletelyUnchanged() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            stack.first is RouteA ? .redirect(to: [RouteB()], retainPending: true) : .deny
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [RouteA()] },
        ]))
        let selectedTabBefore = router.selectedTab
        let tabCountsBefore = router.tabPaths.map(\.count)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://wallet/send"))

        XCTAssertEqual(outcome, .denied)
        XCTAssertEqual(router.selectedTab, selectedTabBefore)
        XCTAssertEqual(router.tabPaths.map(\.count), tabCountsBefore, "the redirect stack must never have been pushed")

        // And nothing was left pending either.
        let callCountBeforeDrain = fakeGuard.callCount
        deepLinkRouter.drainPending()
        XCTAssertEqual(fakeGuard.callCount, callCountBeforeDrain)
    }

    // MARK: - Async / ordering

    func testTwoOpenCallsInImmediateSuccessionEachResolveIndependentlyWithNoCorruption() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [NumberedRoute(value: 1)] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 2)] },
        ]))

        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://wallet/send")), .opened)
        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://settings")), .opened)

        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([NumberedRoute(value: 2)]),
            "the second call's popToRoot must have cleanly replaced the first call's stack"
        )
    }

    func testOpenCalledImmediatelyAfterDrainPendingLeavesConsistentState() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        var allow = false
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            if stack.first is RouteB {
                return .allow
            }
            return allow ? .allow : .redirect(to: [RouteB()], retainPending: true)
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [RouteA()] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 5)] },
        ]))
        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://wallet/send")), .pendingGuard)

        allow = true
        deepLinkRouter.drainPending()
        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.tabPaths[0], expectedDeepLinkPath([NumberedRoute(value: 5)]))
    }
}
