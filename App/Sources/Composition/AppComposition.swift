import AppUIKit
import Core
import Foundation
import Network
import Platform
import Scanner
import Settings
import Shell
import SwiftUI

/// The one place feature modules are named (Source Spec §4.3, Changelog #6).
///
/// It builds the `AppRouter`, an `AppEventBus`, each feature's dependency graph
/// (manual constructor injection — a DI framework is a Non-Goal) and its
/// `RouteProvider`, registers **both** providers on the router, and builds the
/// feature-blind `Shell` on top. Nothing else in the app imports a feature.
///
/// The `eventBus` is injectable so tests pass a fresh `AppEventBus()`; `@main`
/// takes the default `.shared`.
@MainActor
struct AppComposition {
    /// Per-tab navigation state, shared with `ShellView`.
    let router: AppRouter
    /// Process-wide event channel (401 → `UserLoggedOut`, `ScenePhase` → lifecycle).
    let eventBus: AppEventBus
    /// The host ViewModel driving the tab container.
    let shellViewModel: ShellViewModel
    /// Every `RouteProvider` registered on `router`, in registration order.
    /// Exposed for composition tests — the router keeps its own copy private.
    let routeProviders: [any RouteProvider]
    /// Shared session, ready for a network-backed feature to consume
    /// (`mason make ios_mvi_feature --has_network` wires into this). No
    /// shipped feature currently performs IO.
    let sessionManager: any SessionManaging
    /// The composed, refresh-capable client — same rationale as `sessionManager`.
    let apiClient: any APIClient

    /// - Parameters:
    ///   - eventBus: the shared event channel. Defaults to `AppEventBus.shared`
    ///     for `@main`; tests inject a fresh instance.
    ///   - config: tab-layout configuration. Defaults to 3 tabs, Settings (index
    ///     2) selected on cold start.
    ///   - secureCacheStore: session-token persistence, backed by the Keychain
    ///     in production. Tests inject an in-memory fake.
    init(
        eventBus: AppEventBus = .shared,
        config: ShellConfig = ShellConfig(),
        secureCacheStore: SecureCacheStore = KeychainCacheStore(service: "com.iosdigitalwallet.session")
    ) {
        self.eventBus = eventBus

        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        self.router = router

        // --- Feature composition (constructor injection) -----------------------
        let logger = ConsoleLogger()
        let cache = UserDefaultsCacheStore(keyPrefix: "app.cache.", logger: logger)

        (sessionManager, apiClient) = Self.makeNetworkStack(
            eventBus: eventBus,
            logger: logger,
            secureCacheStore: secureCacheStore
        )

        let settingsProvider = SettingsModule.makeRouteProvider(cache: cache, logger: logger)
        let scannerProvider = ScannerModule.makeRouteProvider()

        // app:route-providers:begin
        router.register(settingsProvider)
        router.register(scannerProvider)
        // app:route-providers:end

        routeProviders = [settingsProvider, scannerProvider]

        shellViewModel = ShellViewModel(config: config, router: router, eventBus: eventBus)
    }

    /// Builds the Keychain-backed `SessionManager` and the refresh-capable
    /// `APIClient` on top of it. Factored out of `init` to keep it readable;
    /// the template wires `NoTokenRefresher()` — a real `401` force-logs-out,
    /// the honest default for a domain-neutral template.
    private static func makeNetworkStack(
        eventBus: AppEventBus,
        logger: any Core.Logger,
        secureCacheStore: SecureCacheStore
    ) -> (sessionManager: any SessionManaging, apiClient: any APIClient) {
        let sessionManager = SessionManager(secureCacheStore: secureCacheStore)
        let apiClient = NetworkComposition.makeAPIClient(
            eventBus: eventBus,
            logger: logger,
            sessionManager: sessionManager,
            tokenRefresher: NoTokenRefresher()
        )
        return (sessionManager, apiClient)
    }

    /// The app's root view: the feature-blind `Shell`, bound to `router`.
    var rootView: some View {
        ShellView(viewModel: shellViewModel, router: router)
    }
}
