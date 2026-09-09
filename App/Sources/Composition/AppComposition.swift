import AppUIKit
import Core
import Factory
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
/// (registered on `Factory.Container` for declarative resolution) and its
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
    /// Process-wide theme manager.
    let themeManager: AppThemeManager
    /// Process-wide localization manager.
    let localizationManager: AppLocalizationManager
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
        cacheStore: (any CacheStore)? = nil,
        secureCacheStore: SecureCacheStore = KeychainCacheStore(service: "com.iosdigitalwallet.session")
    ) {
        self.eventBus = eventBus

        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        self.router = router

        // --- Feature composition (Factory registration) ------------------------
        let logger = ConsoleLogger()
        let cache = cacheStore ?? UserDefaultsCacheStore(keyPrefix: "app.cache.", logger: logger)

        let themeManager = AppThemeManager(cache: cache, eventBus: eventBus)
        self.themeManager = themeManager
        AppThemeManager.shared = themeManager

        let localizationManager = AppLocalizationManager(cache: cache, eventBus: eventBus)
        self.localizationManager = localizationManager
        AppLocalizationManager.shared = localizationManager

        (sessionManager, apiClient) = Self.makeNetworkStack(
            eventBus: eventBus,
            logger: logger,
            secureCacheStore: secureCacheStore
        )

        // Register production dependencies on Factory Container
        Container.shared.registerSettingsRepository(
            cache: cache,
            apiClient: apiClient,
            logger: logger
        )
        Container.shared.settingsLocalizationService.register { localizationManager }

        let settingsProvider = SettingsRouteProvider { SettingsViewModel() }
        let scannerProvider = ScannerRouteProvider { ScannerViewModel() }

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
