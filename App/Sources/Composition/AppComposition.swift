import AppUIKit
import Core
import Foundation
import Platform
import ScannerFeature
import SettingsFeature
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

    /// - Parameters:
    ///   - eventBus: the shared event channel. Defaults to `AppEventBus.shared`
    ///     for `@main`; tests inject a fresh instance.
    ///   - config: tab-layout configuration. Defaults to 3 tabs, Settings (index
    ///     2) selected on cold start.
    init(eventBus: AppEventBus = .shared, config: ShellConfig = ShellConfig()) {
        self.eventBus = eventBus

        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        self.router = router

        // --- Feature composition (constructor injection) -----------------------
        let logger = ConsoleLogger()
        let cache = UserDefaultsCacheStore(keyPrefix: "app.cache.", logger: logger)

        let settingsProvider = SettingsFeatureModule.makeRouteProvider(cache: cache, logger: logger)
        let scannerProvider = ScannerFeatureModule.makeRouteProvider()

        // app:route-providers:begin
        router.register(settingsProvider)
        router.register(scannerProvider)
        // app:route-providers:end

        routeProviders = [settingsProvider, scannerProvider]

        shellViewModel = ShellViewModel(config: config, router: router, eventBus: eventBus)
    }

    /// The app's root view: the feature-blind `Shell`, bound to `router`.
    var rootView: some View {
        ShellView(viewModel: shellViewModel, router: router)
    }
}
