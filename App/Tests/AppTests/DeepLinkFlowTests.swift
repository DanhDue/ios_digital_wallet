import Combine
import Platform
import Scanner
import XCTest
@testable import iOSDigitalWallet

/// Tier C — the epic's acceptance evidence (Source Spec §10 Tier C): every
/// scenario here drives `AppComposition.deepLinkRouter.open(url:)` (or, for
/// scenario 6, `AppRouter.navigate(to:)` directly) through the *composed*
/// app — real `AppRouter`, real `ScannerRouteProvider` / `SettingsRouteProvider`,
/// real `ShellTabResolver` — exactly the wiring `iOSDigitalWalletApp.onOpenURL`
/// drives in production. Only the `DeepLinkGuard` is ever swapped (scenarios
/// 3 and 4), through the `deepLinkGuard:` seam `AppComposition` already
/// exposes (Task 8) — never a new one.
///
/// **Scheme note.** The registered scheme is `iosdigitalwallet://`
/// (`Module.deepLinkScheme`), but `DeepLinkRouter.open(_:)` deliberately does
/// not validate scheme or host (`DeepLink.init?` only decomposes the URL), so
/// every scenario below uses `app://` as shorthand — exactly the convention
/// `DeepLinkCompositionTests.swift` already established. The real scheme
/// only matters for the OS-level delivery hop, which is what the UI test
/// (`App/UITests/DeepLinkOpenURLUITests.swift`) exists to prove instead.
///
/// **On "renders the result screen".** The brief's wording for scenarios 2,
/// 4 and 6 was tested literally first: a helper walked the hosted `UIView`
/// tree for `ResultView`'s `"scanner.result.code"` accessibility identifier.
/// On this SDK that walk finds nothing — dumping the full hierarchy under a
/// real, key `UIWindow` after the standard `RunLoop` pump shows the
/// `HostingView` node for the pushed destination with **zero** UIKit
/// subviews; SwiftUI's `Text` does not materialise as an identifier-bearing
/// `UIView` here, so no amount of extra pump time fixes it. An earlier
/// revision of this file then fell back to `XCTAssertNotNil(window
/// .rootViewController?.view)` as a substitute and mislabelled it a "not
/// blank" proof — that is false: `UIViewController.view` force-loads on
/// access, so that assertion cannot fail short of a crash, and a review
/// caught it reproducing defect D3 (swap `ShellView`'s destination closure
/// for `EmptyView()`) while staying green. It has been removed.
///
/// **What actually proves non-blank rendering here is `NavigationFlowTests`
/// .swift`'s own D3 regression test** (`testPushingARouteWithNoAppRoutesEntry
/// ResolvesThroughTheErasedDestinationInsteadOfBlank`): a spy `RouteProvider`
/// whose `destinationCallCount` is asserted `> 0` — falsifiable, because a
/// spy can stand in for the *sole* provider claiming an otherwise-unclaimed
/// route. That technique does not transfer here: `ScannerResultRoute`
/// already has a real, AppComposition-registered `ScannerRouteProvider`
/// claiming it, and `AppRouter.destination(for:)` resolves via
/// `providers.first(where:)` — first match wins, so a spy registered
/// afterward is never consulted. **What this file proves in-process instead
/// is route identity and payload**: `expectedDeepLinkPath(_:)`
/// (`TestSupport.swift`) builds the exact `NavigationPath` `AppRouter
/// .navigate` would produce and compares it via `XCTAssertEqual` against
/// `tabPaths[i]` — falsifiable against the concrete route type, not just its
/// count, and against the carried payload (e.g. `"ABC123"`). Literal
/// on-screen rendering — the thing a spy or a path comparison cannot reach
/// once the real provider already claims the route — is proved instead by
/// `DeepLinkOpenURLUITests`, which reads `"scanner.result.code"`'s actual
/// `.label` through XCUITest's real accessibility-tree query. **That UI test
/// is consequently the single point of failure for an in-process,
/// already-claimed-route blank-screen regression** (e.g. `ShellView`'s
/// `.navigationDestination` closure silently returning `EmptyView()`); no
/// test in this file can catch that class of defect, and none claims to
/// anymore.
@MainActor
final class DeepLinkFlowTests: XCTestCase {
    // MARK: - Scenario 1 — /settings selects tab 2 without duplicating its root

    func testOpeningSettingsDeepLinkSelectsSettingsTabWithoutDuplicatingItsRoot() {
        let sut = makeComposition()
        // Cold start already selects tab 2 (Settings) — move away first so the
        // assertion below proves the link actually moved the tab, not that it
        // coincidentally started there.
        sut.router.switchTab(0)

        let outcome = sut.deepLinkRouter.open(deepLinkTestURL("app://settings"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(sut.router.selectedTab, 2)
        XCTAssertEqual(
            sut.router.tabPaths[2].count,
            0,
            "the isTabRoot rule must drop SettingsRoot, not push a duplicate"
        )
        XCTAssertEqual(sut.router.tabPaths[0].count, 0, "tab 0 must be untouched")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "tab 1 must be untouched")
    }

    // MARK: - Scenario 2 — /scanner/result/:code selects tab 1, drops the root, carries the code

    func testOpeningScannerResultDeepLinkSelectsScannerTabDropsRootAndCarriesTheCode() {
        let sut = makeComposition()

        let outcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123"))

        XCTAssertEqual(outcome, .opened)
        XCTAssertEqual(sut.router.selectedTab, 1)
        XCTAssertEqual(sut.router.tabPaths[1].count, 1, "ScannerRoot must be dropped — only ScannerResultRoute remains")
        XCTAssertEqual(sut.router.tabPaths[0].count, 0)
        XCTAssertEqual(sut.router.tabPaths[2].count, 0)

        // Route identity and payload, not just depth: this fails if the
        // wrong route type were pushed (e.g. ScannerRoot left in) or if the
        // captured code were dropped or mangled anywhere along
        // match → build → resolve → navigate.
        XCTAssertEqual(
            sut.router.tabPaths[1],
            expectedDeepLinkPath([ScannerResultRoute(code: "ABC123")]),
            "must push exactly ScannerResultRoute(code: \"ABC123\") — not the root, not a different code"
        )
    }

    // MARK: - Scenario 3 — a guard that denies without a session redirects and retains the link pending

    func testAGuardThatDeniesWithoutASessionRedirectsToSettingsAndRetainsThePendingLink() {
        let guardDouble = FakeDeepLinkGuard { stack, _ in
            if stack.first is AppRoutes.SettingsRoot {
                // Redirect targets are evaluated once more, with
                // requiresAuth: false, and MUST be reachable — mirrors
                // SessionDeepLinkGuard's own contract.
                return .allow
            }
            if stack.contains(where: { $0 is ScannerResultRoute }) {
                return .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
            }
            return .allow
        }
        let sut = makeComposition(guard: guardDouble)

        let outcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123"))

        XCTAssertEqual(outcome, .pendingGuard)
        XCTAssertEqual(sut.router.selectedTab, 2, "the redirect target (SettingsRoot) must be shown")
        XCTAssertEqual(sut.router.tabPaths[2].count, 0, "SettingsRoot is tab 2's own root — not duplicated")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "the original ScannerResult stack must never have been pushed")

        // Prove something is genuinely pending: `drainPending()` is
        // documented as a no-op when nothing is stored (`guard let
        // pendingLink = pending else { return }`), so a call count that
        // does NOT move proves nothing was retained. This guard still
        // denies (no session flip in this scenario), so draining re-runs
        // resolve() and the count must move.
        let callCountBeforeDrain = guardDouble.callCount
        sut.deepLinkRouter.drainPending()
        XCTAssertGreaterThan(
            guardDouble.callCount,
            callCountBeforeDrain,
            "drainPending() must have consulted the guard again — proof a link was actually pending"
        )
    }

    // MARK: - Scenario 4 — UserLoggedIn drains the pending link and completes the original navigation

    func testPublishingUserLoggedInDrainsThePendingLinkAfterAGuardRedirect() {
        var hasSession = false
        let guardDouble = FakeDeepLinkGuard { stack, _ in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow
            }
            if stack.contains(where: { $0 is ScannerResultRoute }), !hasSession {
                return .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
            }
            return .allow
        }
        let sut = makeComposition(guard: guardDouble)

        let firstOutcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123"))
        XCTAssertEqual(firstOutcome, .pendingGuard, "test setup: the link must be pending before login")
        XCTAssertEqual(sut.router.selectedTab, 2, "test setup: parked on the redirect target")

        // Simulate the user completing sign-in, then replay — deterministically:
        // `DeepLinkReplayObserver` subscribes to UserLoggedIn with
        // `.receive(on: DispatchQueue.main)` at AppComposition.init time, so
        // its dispatched drainPending() is enqueued on the main queue BEFORE
        // this test's own same-scheduling subscription (subscribed after,
        // below) — waiting on THIS expectation therefore guarantees the
        // replay's queued work already ran. No fixed-duration sleep.
        hasSession = true
        let replayObserved = expectation(description: "UserLoggedIn observed on the main queue after the replay hop")
        var cancellable: AnyCancellable?
        cancellable = sut.eventBus.on(UserLoggedIn.self)
            .receive(on: DispatchQueue.main)
            .sink { _ in replayObserved.fulfill() }
        sut.eventBus.publish(UserLoggedIn())
        wait(for: [replayObserved], timeout: 2)
        cancellable?.cancel()

        XCTAssertEqual(sut.router.selectedTab, 1, "the replayed link must land on the Scanner tab")
        XCTAssertEqual(sut.router.tabPaths[1].count, 1, "ScannerRoot dropped, ScannerResultRoute pushed")
        XCTAssertEqual(sut.router.tabPaths[2].count, 0, "the earlier redirect parking must not persist as extra state")

        // Route identity and payload survive the redirect → pending → replay
        // round trip intact — not just that *something* landed on depth 1.
        XCTAssertEqual(
            sut.router.tabPaths[1],
            expectedDeepLinkPath([ScannerResultRoute(code: "ABC123")]),
            "the replayed stack must be exactly ScannerResultRoute(code: \"ABC123\") — the original payload, unmangled"
        )

        // Pending store empty: a second drain must be a true no-op.
        let callCountAfterReplay = guardDouble.callCount
        sut.deepLinkRouter.drainPending()
        XCTAssertEqual(
            guardDouble.callCount,
            callCountAfterReplay,
            "nothing must be pending after a successful replay — a second drain must not consult the guard"
        )
    }

    // MARK: - Scenario 5 — an unmatched link leaves the router byte-for-byte unchanged

    func testAnUnmatchedLinkLeavesEveryRouterStateByteForByteUnchanged() {
        let sut = makeComposition()
        // Build up non-trivial state first so "unchanged" is a real assertion,
        // not a vacuous one over an already-empty router.
        sut.router.navigate(to: AppRoutes.SettingsRoot(), inTab: 2)
        sut.router.switchTab(1)
        let selectedTabBefore = sut.router.selectedTab
        let tabPathCountsBefore = sut.router.tabPaths.map(\.count)

        let outcome = sut.deepLinkRouter.open(deepLinkTestURL("app://nope"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(sut.router.selectedTab, selectedTabBefore)
        XCTAssertEqual(sut.router.tabPaths.map(\.count), tabPathCountsBefore)
    }

    // MARK: - Scenario 6 — regression D3: direct navigate(to:) to a feature-private route

    /// Bypasses the deep-link engine entirely — this is `AppRouter.navigate(to:)`
    /// driven directly, the case D3 made impossible before Task 1's `AnyAppRoute`
    /// erasure: `ScannerResultRoute` has no `AppRoutes` entry, so before the fix
    /// `ShellView`'s per-type `.navigationDestinations` would have named it and
    /// rendered nothing.
    ///
    /// **This test proves the route is accepted and stored with its exact
    /// identity and payload — it does not, and cannot, prove the screen
    /// renders rather than staying blank.** See the type doc comment: that
    /// proof requires literal on-screen content, which only
    /// `DeepLinkOpenURLUITests` can reach once a real provider already
    /// claims the route.
    func testDirectlyNavigatingToScannerResultRouteStoresItsExactIdentityAndPayload() {
        let sut = makeComposition()
        sut.router.switchTab(1)
        sut.router.navigate(to: ScannerResultRoute(code: "XYZ789"), inTab: 1)

        XCTAssertEqual(
            sut.router.tabPaths[1],
            expectedDeepLinkPath([ScannerResultRoute(code: "XYZ789")]),
            "must store exactly ScannerResultRoute(code: \"XYZ789\") — the erasure must not lose or substitute it"
        )
    }

    // MARK: - Extended BVA — ordering (brief's dual-persona phase)

    /// Equivalence partition on "which link most recently ran": two links
    /// opened in immediate succession must leave the router in exactly the
    /// second link's state, with no residue from the first.
    func testTwoLinksOpenedInImmediateSuccessionLeaveOnlyTheSecondsStateActive() {
        let sut = makeComposition()

        let firstOutcome = sut.deepLinkRouter.open(deepLinkTestURL("app://settings"))
        let secondOutcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123"))

        XCTAssertEqual(firstOutcome, .opened)
        XCTAssertEqual(secondOutcome, .opened)
        XCTAssertEqual(sut.router.selectedTab, 1, "the second link must win")
        XCTAssertEqual(sut.router.tabPaths[1].count, 1)
        XCTAssertEqual(sut.router.tabPaths[2].count, 0, "the first link's visit must leave no residue")
    }

    /// Boundary on `DeepLinkRouter`'s single-slot pending store (documented
    /// "no TTL, a newer link always supersedes an older one"): opening a
    /// second guard-redirected link while the first is still pending must
    /// discard the first, so draining replays only the second.
    func testANewerPendingLinkSupersedesAnOlderStillPendingOne() {
        let guardDouble = FakeDeepLinkGuard { stack, _ in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow
            }
            return .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
        }
        let sut = makeComposition(guard: guardDouble)

        let firstOutcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/FIRST01"))
        let secondOutcome = sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/SECOND2"))
        XCTAssertEqual(firstOutcome, .pendingGuard)
        XCTAssertEqual(secondOutcome, .pendingGuard)

        // Now let the guard allow everything (simulating sign-in) and drain:
        // only ONE link can possibly replay. Since both candidate stacks
        // share the identical shape ([ScannerRoot, ScannerResultRoute]), the
        // discriminator has to be the guard's own observed call sequence,
        // not router state (both would look identical) — the guard is only
        // ever consulted again for a SECOND link if the first one's pending
        // slot was overwritten rather than queued.
        let callCountBeforeDrain = guardDouble.callCount
        guardDouble.decide = { _, _ in .allow }
        sut.deepLinkRouter.drainPending()

        XCTAssertEqual(sut.router.selectedTab, 1)
        XCTAssertEqual(sut.router.tabPaths[1].count, 1, "exactly one link replays — the slot never queued both")
        XCTAssertEqual(
            guardDouble.callCount,
            callCountBeforeDrain + 1,
            "draining a single-slot pending store consults the guard exactly once, proving only one link survived"
        )
    }
}
