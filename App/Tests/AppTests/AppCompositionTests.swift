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
        // break this shipped test.
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertFalse(sut.routeProviders.isEmpty)

        let handlesSettings = sut.routeProviders.filter { $0.canHandle(AppRoutes.SettingsRoot()) }
        XCTAssertEqual(handlesSettings.count, 1, "exactly one provider handles SettingsRoot")
    }

    func testRouterResolvesSettingsRoot() {
        let sut = AppComposition(eventBus: AppEventBus())

        // Resolves through the router the same way the shell resolves a tab root.
        _ = sut.router.destination(for: AppRoutes.SettingsRoot())
    }

    func testRouterIsBuiltWithConfiguredTabsAndSettingsSelected() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.router.tabPaths.count, sut.shellViewModel.config.tabCount)
        XCTAssertEqual(sut.router.selectedTab, sut.shellViewModel.config.initialTab)
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

    func testDeepLinkRouterResolvesSettingsPattern() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.deepLinkRouter.open(deepLinkTestURL("app://settings")), .opened)
        XCTAssertEqual(
            sut.router.selectedTab,
            sut.shellViewModel.config.initialTab,
            "Settings' /settings lands on Settings tab"
        )
        XCTAssertEqual(
            sut.router.tabPaths[sut.shellViewModel.config.initialTab].count,
            0,
            "SettingsRoot is tab's own root — no duplicate push"
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
}
