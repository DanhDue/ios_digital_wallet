import Combine
import Core
import Network
import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Tier A — composition-root behavior.
@MainActor
final class AppCompositionTests: XCTestCase {
    // MARK: Route-provider registration

    func testCompositionRegistersAProviderForEachShippedFeatureRoot() {
        // Asserts presence, not an exact count: a consumer adding a feature via
        // `mason make ios_mvi_feature` + wiring it into AppComposition must NOT
        // break this shipped test. It only guarantees the two template features
        // stay wired.
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertFalse(sut.routeProviders.isEmpty)

        let handlesSettings = sut.routeProviders.filter { $0.canHandle(AppRoutes.SettingsRoot()) }
        let handlesScanner = sut.routeProviders.filter { $0.canHandle(AppRoutes.ScannerRoot()) }
        XCTAssertEqual(handlesSettings.count, 1, "exactly one provider handles SettingsRoot")
        XCTAssertEqual(handlesScanner.count, 1, "exactly one provider handles ScannerRoot")
    }

    func testRouterResolvesBothSharedRoots() {
        let sut = AppComposition(eventBus: AppEventBus())

        // Resolves through the router the same way the shell resolves a tab root.
        _ = sut.router.destination(for: AppRoutes.SettingsRoot())
        _ = sut.router.destination(for: AppRoutes.ScannerRoot())
    }

    func testRouterIsBuiltWithThreeTabsAndSettingsSelected() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.router.tabPaths.count, 3)
        XCTAssertEqual(sut.router.selectedTab, 2)
    }

    // MARK: 401 → UserLoggedOut (exactly once)

    func test401FromTheComposedAPIClientPublishesExactlyOneUserLoggedOut() async {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(UserLoggedOut.self))

        let client = NetworkComposition.makeAPIClient(
            eventBus: bus,
            session: .stubbed401(),
            logger: SilentLogger()
        )

        do {
            let _: EmptyResponse = try await client.send(APIRequest(method: .get, path: "ping"))
            XCTFail("expected the 401 to throw")
        } catch {
            // NetworkError.unauthorized — expected.
        }

        XCTAssertEqual(recorder.count, 1, "exactly one UserLoggedOut per 401 response")
    }

    // MARK: 401 → UserLoggedOut, specific `LogoutReason`

    func test401WithNoRefreshTokenPublishesUserLoggedOutWithMissingRefreshTokenReason() async {
        // Case 3 (spec §4 decision table): a 401 with `session.refreshToken == nil`.
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(UserLoggedOut.self))

        let client = NetworkComposition.makeAPIClient(
            eventBus: bus,
            session: .stubbed401(),
            logger: SilentLogger(),
            sessionManager: SessionManager(),
            tokenRefresher: NoTokenRefresher()
        )

        do {
            let _: EmptyResponse = try await client.send(APIRequest(method: .get, path: "ping"))
            XCTFail("expected the 401 to throw")
        } catch {
            // NetworkError.unauthorized — expected.
        }

        XCTAssertEqual(recorder.count, 1, "exactly one UserLoggedOut per 401 response")
        XCTAssertEqual(recorder.values.first?.reason, .missingRefreshToken)
    }

    func test401WithARefreshTokenAndNoTokenRefresherPublishesUserLoggedOutWithRefreshFailedReason() async {
        // Case 2 (spec §4 decision table): a refresh token is present, but the
        // wired `NoTokenRefresher` always returns `.failure(.invalidGrant)` —
        // proof the composed client uses `RefreshingAuthInterceptor`, not
        // `AuthTokenInterceptor` (which could never produce `.refreshFailed`).
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(UserLoggedOut.self))
        let sessionManager = SessionManager()
        sessionManager.update(accessToken: "old", refreshToken: "old-refresh")

        let client = NetworkComposition.makeAPIClient(
            eventBus: bus,
            session: .stubbed401(),
            logger: SilentLogger(),
            sessionManager: sessionManager,
            tokenRefresher: NoTokenRefresher()
        )

        do {
            let _: EmptyResponse = try await client.send(APIRequest(method: .get, path: "ping"))
            XCTFail("expected the 401 to throw")
        } catch {
            // NetworkError.unauthorized — expected.
        }

        XCTAssertEqual(recorder.count, 1, "exactly one UserLoggedOut per 401 response")
        XCTAssertEqual(recorder.values.first?.reason, .refreshFailed)
    }

    // MARK: makeBareAPIClient — structurally incapable of notifying a sink

    func testMakeBareAPIClientOn401ThrowsUnauthorizedAndPublishesNoUserLoggedOut() async {
        // `makeBareAPIClient` has no `eventBus` / `authEventSink` parameter at
        // all, so nothing it does can reach any bus. Attach a recorder to an
        // unrelated bus to prove no leak occurs during the call.
        let unrelatedBus = AppEventBus()
        let recorder = Recorder(unrelatedBus.on(UserLoggedOut.self))

        let client = NetworkComposition.makeBareAPIClient(
            session: .stubbed401(),
            logger: SilentLogger()
        )

        do {
            let _: EmptyResponse = try await client.send(APIRequest(method: .get, path: "auth/refresh"))
            XCTFail("expected the 401 to throw")
        } catch NetworkError.unauthorized {
            // expected
        } catch {
            XCTFail("expected NetworkError.unauthorized, got \(error)")
        }

        XCTAssertEqual(recorder.count, 0, "makeBareAPIClient has no sink reference; nothing can publish")
    }

    // MARK: AppComposition — SessionManager backed by the injected SecureCacheStore

    func testAppCompositionSessionManagerIsBackedByTheInjectedSecureCacheStore() {
        let fakeStore = InMemorySecureCacheStore()
        let sut = AppComposition(eventBus: AppEventBus(), secureCacheStore: fakeStore)

        sut.sessionManager.update(accessToken: "a", refreshToken: "r")

        XCTAssertEqual(fakeStore.get(String.self, key: "core.session.access"), "a")
        XCTAssertEqual(fakeStore.get(String.self, key: "core.session.refresh"), "r")
    }

    func testAppCompositionWithDefaultSecureCacheStoreConstructsWithoutCrashing() {
        // Smoke test only — the real system Keychain is legitimate in a
        // simulator, but its content is not asserted here.
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertNil(sut.sessionManager.accessToken, "a freshly composed session starts empty")
    }

    // MARK: Lifecycle mapping

    func testScenePhaseBackgroundPublishesBackgroundThenActivePublishesForeground() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.background)
        observer.handle(ScenePhase.active)

        XCTAssertEqual(recorder.values, [.background, .foreground])
    }

    func testRapidActiveBackgroundActivePublishesInThatExactOrder() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.active)
        observer.handle(ScenePhase.background)
        observer.handle(ScenePhase.active)

        XCTAssertEqual(recorder.values, [.foreground, .background, .foreground])
    }

    func testInactivePhaseMapsToInactive() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.inactive)

        XCTAssertEqual(recorder.values, [.inactive])
    }

    // MARK: Theme & Localization managers composition

    func testAppCompositionExposesThemeManagerAndLocalizationManager() {
        let bus = AppEventBus()
        let testDefaults = UserDefaults(suiteName: "AppCompositionTests") ?? .standard
        testDefaults.removePersistentDomain(forName: "AppCompositionTests")
        let cache = UserDefaultsCacheStore(defaults: testDefaults, keyPrefix: "test.")
        let sut = AppComposition(eventBus: bus, cacheStore: cache)

        XCTAssertNotNil(sut.themeManager)
        XCTAssertNotNil(sut.localizationManager)
        XCTAssertEqual(sut.themeManager.mode, .system)
        XCTAssertEqual(sut.localizationManager.currentLanguageCode, "en")
    }

    func testRootViewInstantiatesWithComposition() {
        let sut = AppComposition(eventBus: AppEventBus())
        let rootView = RootView(composition: sut)
        XCTAssertNotNil(rootView.body)
    }

    // MARK: DeepLinkRouter — one resolvable entry per pattern the shipped features declare

    func testDeepLinkRouterResolvesEveryPatternTheShippedFeaturesDeclare() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://settings")), .opened)
        XCTAssertEqual(sut.router.selectedTab, 2, "Settings' /settings lands on tab 2")
        XCTAssertEqual(sut.router.tabPaths[2].count, 0, "SettingsRoot is tab 2's own root — no duplicate push")

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner")), .opened)
        XCTAssertEqual(sut.router.selectedTab, 1, "Scanner's /scanner lands on tab 1")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "ScannerRoot is tab 1's own root — no duplicate push")

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner/result/ABC123")), .opened)
        XCTAssertEqual(sut.router.selectedTab, 1)
        XCTAssertEqual(
            sut.router.tabPaths[1].count, 1,
            "ScannerRoot dropped as tab 1's own root; only ScannerResultRoute pushed"
        )
    }

    // MARK: DeepLinkGuard injection seam

    func testAppCompositionWithNoInjectedGuardUsesTheProductionSessionBasedGuard() {
        // The default is SessionDeepLinkGuard(session: sut.sessionManager, redirectTo: []) —
        // no shipped route requires auth, so a fake gated provider is registered
        // directly on the built router to observe the production default's behavior.
        let sut = AppComposition(eventBus: AppEventBus())
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/private", requiresAuth: true) { _ in [AppRoutes.SettingsRoot()] },
        ]))

        XCTAssertEqual(
            sut.deepLinkRouter.open(deepLinkTestURL("app://private")),
            .denied,
            "no token, no configured redirect ⇒ the production guard denies"
        )
    }

    func testAppCompositionWithAnInjectedGuardUsesThatGuardInsteadOfTheDefault() {
        let fakeGuard = FakeDeepLinkGuard { _, _ in .allow }
        let sut = AppComposition(eventBus: AppEventBus(), deepLinkGuard: fakeGuard)
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/private", requiresAuth: true) { _ in [AppRoutes.SettingsRoot()] },
        ]))

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://private")), .opened)
        XCTAssertEqual(fakeGuard.callCount, 1, "the injected guard, not a production one, must have been consulted")
    }

    // MARK: UserLoggedIn -> drainPending()

    func testPublishingUserLoggedInDrainsAPendingRedirectedLink() {
        var allow = false
        let fakeGuard = FakeDeepLinkGuard { stack, requiresAuth in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow // the redirect target itself, evaluated with requiresAuth: false
            }
            guard requiresAuth else { return .allow }
            return allow ? .allow : .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
        }
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus, deepLinkGuard: fakeGuard)
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/gated", requiresAuth: true) { _ in [AppRoutes.ScannerRoot()] },
        ]))

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://gated")), .pendingGuard)
        XCTAssertEqual(sut.router.selectedTab, 2, "redirected to SettingsRoot (tab 2) while pending")

        allow = true
        bus.publish(UserLoggedIn())
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(sut.router.selectedTab, 1, "drainPending replayed the original stack onto Scanner (tab 1)")
    }

    func testPublishingAnUnrelatedEventDoesNotDrainAPendingLink() {
        let fakeGuard = FakeDeepLinkGuard { stack, requiresAuth in
            if stack.first is AppRoutes.SettingsRoot {
                return .allow
            }
            guard requiresAuth else { return .allow }
            return .redirect(to: [AppRoutes.SettingsRoot()], retainPending: true)
        }
        let bus = AppEventBus()
        let sut = AppComposition(eventBus: bus, deepLinkGuard: fakeGuard)
        sut.deepLinkRouter.register(FakeDeepLinkRouteProvider([
            DeepLinkRoute("/gated", requiresAuth: true) { _ in [AppRoutes.ScannerRoot()] },
        ]))

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://gated")), .pendingGuard)
        XCTAssertEqual(sut.router.selectedTab, 2)

        bus.publish(AppLifecycleChanged(state: .background))
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(sut.router.selectedTab, 2, "an unrelated event must never drain the pending link")
    }

    // MARK: Adversarial

    func testOpeningAURLThatMatchesNoRegisteredPatternLeavesRouterStateUnchanged() {
        let sut = AppComposition(eventBus: AppEventBus())
        let selectedTabBefore = sut.router.selectedTab
        let tabCountsBefore = sut.router.tabPaths.map(\.count)

        let outcome = sut.deepLinkRouter.open(deepLinkTestURL("app://no-such-route"))

        XCTAssertEqual(outcome, .unmatched)
        XCTAssertEqual(sut.router.selectedTab, selectedTabBefore)
        XCTAssertEqual(sut.router.tabPaths.map(\.count), tabCountsBefore)
    }

    func testTwoURLsOpenedInImmediateSuccessionResolveIndependentlyWithTheSecondWinning() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://settings")), .opened)
        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://scanner")), .opened)

        XCTAssertEqual(sut.router.selectedTab, 1, "the second call's tab must win cleanly")
        XCTAssertEqual(sut.router.tabPaths[1].count, 0, "ScannerRoot, its own tab root — no leftover state")
    }
}
