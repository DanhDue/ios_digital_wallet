import Core
import SwiftUI
import XCTest
@testable import Platform

/// `DeepLinkRouter` gating (allow / redirect / deny) and redirect
/// re-entrancy scenarios. See `DeepLinkRouterTests` for the split rationale
/// and the shared `deepLinkTestURL(_:)` / `expectedDeepLinkPath(_:)` helpers.
@MainActor
final class DeepLinkRouterGatingTests: XCTestCase {
    // MARK: - Gating

    func testOpenWithNoGuardConfiguredAllowsByDefault() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let deepLinkRouter = DeepLinkRouter(router: router)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
    }

    func testGuardReturningAllowNavigatesAndReturnsOpened() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { _, _ in .allow }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(router.tabPaths[0], expectedDeepLinkPath([RouteA()]))
    }

    func testGuardRedirectWithRetainPendingTrueStoresPendingPushesRedirectStackAndReturnsPendingGuard() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            stack.first is RouteA ? .redirect(to: [RouteB()], retainPending: true) : .allow
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .pendingGuard)
        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([RouteB()]),
            "the redirect stack is pushed, not the original"
        )
        XCTAssertEqual(fakeGuard.callCount, 2, "original stack once, then the redirect target once")
    }

    func testGuardRedirectWithRetainPendingFalseStoresNothing() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            stack.first is RouteA ? .redirect(to: [RouteB()], retainPending: false) : .allow
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))
        XCTAssertEqual(outcome, .pendingGuard)
        let callCountAfterOpen = fakeGuard.callCount

        deepLinkRouter.drainPending()

        XCTAssertEqual(
            fakeGuard.callCount,
            callCountAfterOpen,
            "nothing was stored, so drainPending must not re-evaluate"
        )
        XCTAssertEqual(
            router.tabPaths[0],
            expectedDeepLinkPath([RouteB()]),
            "drainPending must not have changed the stack again"
        )
    }

    /// Fix-round-1 Finding 3 (minor): a guard returning `.redirect(to: [])`
    /// is a host bug — an empty redirect target pushes nothing — but it must
    /// not be silent. `navigate(stack:)`'s empty-stack guard now logs,
    /// matching the symmetric empty-`build()` case already logged in
    /// `open(_:)`. The returned outcome deliberately stays `.pendingGuard`:
    /// changing it is a spec decision out of scope for this fix.
    func testRedirectToEmptyStackLogsExactlyOnce() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            stack.first is RouteA ? .redirect(to: [], retainPending: true) : .allow
        }
        let logger = FakeLogger()
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard, logger: logger)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .pendingGuard, "the outcome is deliberately unchanged by this fix")
        XCTAssertEqual(router.tabPaths[0].count, 0, "there is nothing to push")
        XCTAssertEqual(logger.errorCount, 1, "an empty redirect target must not be silent")
    }

    func testGuardDenyingReturnsDeniedAndClearsAnyPendingLink() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        var callCount = 0
        let fakeGuard = FakeDeepLinkGuard { _, _ in
            callCount += 1
            // First call (the original /wallet/send link): redirect and retain.
            // Second call (redirect target): allow, so pending really gets stored.
            // Third call (the new /settings link): deny outright.
            if callCount == 1 {
                return .redirect(to: [RouteB()], retainPending: true)
            }
            if callCount == 2 {
                return .allow
            }
            return .deny
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send") { _ in [RouteA()] },
            DeepLinkRoute("/settings") { _ in [NumberedRoute(value: 1)] },
        ]))
        XCTAssertEqual(deepLinkRouter.open(deepLinkTestURL("app://wallet/send")), .pendingGuard)

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .denied)
        // Draining now must be a no-op: the deny cleared the pending link
        // stored by the first /wallet/send call.
        let callCountBeforeDrain = fakeGuard.callCount
        deepLinkRouter.drainPending()
        XCTAssertEqual(fakeGuard.callCount, callCountBeforeDrain, "deny must have cleared the pending link")
    }

    func testRequiresAuthTrueReachesTheGuardUnchanged() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard()
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send", requiresAuth: true) { _ in [RouteA()] },
        ]))

        _ = deepLinkRouter.open(deepLinkTestURL("app://wallet/send"))

        XCTAssertEqual(fakeGuard.invocations.first?.requiresAuth, true)
    }

    func testRequiresAuthFalseReachesTheGuardUnchanged() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard()
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings", requiresAuth: false) { _ in [RouteA()] },
        ]))

        _ = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(fakeGuard.invocations.first?.requiresAuth, false)
    }

    // MARK: - Redirect re-entrancy

    /// A guard that redirects its own redirect target must terminate. The
    /// router evaluates the redirect target exactly once; a bounded call
    /// count (not merely "no hang") is what proves it never recursed.
    func testRedirectTargetThatDoesNotEvaluateToAllowYieldsDeniedWithoutRecursing() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { _, _ in
            // Every call — original AND redirect target — redirects again.
            // A recursive implementation would spin forever on this.
            .redirect(to: [RouteB()], retainPending: true)
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/settings") { _ in [RouteA()] },
        ]))

        let outcome = deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .denied)
        XCTAssertEqual(fakeGuard.callCount, 2, "original stack once, redirect target once — never a third call")
    }

    func testRedirectTargetIsEvaluatedWithRequiresAuthFalseRegardlessOfTheOriginalRoute() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let fakeGuard = FakeDeepLinkGuard { stack, _ in
            stack.first is RouteA ? .redirect(to: [RouteB()], retainPending: true) : .allow
        }
        let deepLinkRouter = DeepLinkRouter(router: router, guard: fakeGuard)
        deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/wallet/send", requiresAuth: true) { _ in [RouteA()] },
        ]))

        _ = deepLinkRouter.open(deepLinkTestURL("app://wallet/send"))

        guard fakeGuard.invocations.count == 2 else {
            XCTFail("expected exactly 2 guard invocations, got \(fakeGuard.invocations.count)")
            return
        }
        XCTAssertEqual(fakeGuard.invocations[0].requiresAuth, true, "the original route's declared requiresAuth")
        XCTAssertEqual(fakeGuard.invocations[1].requiresAuth, false, "a redirect target must be reachable without auth")
    }
}
