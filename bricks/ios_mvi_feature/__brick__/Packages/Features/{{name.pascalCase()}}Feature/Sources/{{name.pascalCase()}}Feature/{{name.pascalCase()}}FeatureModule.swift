import Core{{#has_network}}
import Network{{/has_network}}

/// The `{{name.pascalCase()}}` feature's composition root — the **only** place
/// `Data` → `Domain` → `Presentation` are wired together.
///
/// It lives at the package root, outside `Data/` · `Domain/` · `Presentation/`,
/// on purpose: ArchTests K2/K3/K4 scan those folders, and only this file is
/// allowed to name the `internal` `Data` type
/// `{{name.pascalCase()}}RepositoryImpl` while still being `public` for the `App`
/// composition root to call.
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/SettingsFeatureModule.swift
public enum {{name.pascalCase()}}FeatureModule {
    /// Builds a ready-to-register `{{name.pascalCase()}}RouteProvider`. A fresh
    /// `{{name.pascalCase()}}ViewModel` is created per navigation.
    @MainActor
    public static func makeRouteProvider(
        cache: any CacheStore,{{#has_network}}
        apiClient: any APIClient,{{/has_network}}
        logger: any Logger
    ) -> {{name.pascalCase()}}RouteProvider {
        {{name.pascalCase()}}RouteProvider {
            makeViewModel(cache: cache, {{#has_network}}apiClient: apiClient, {{/has_network}}logger: logger)
        }
    }

    /// Builds a `{{name.pascalCase()}}ViewModel` directly, for a host that manages
    /// its own navigation.
    @MainActor
    public static func makeViewModel(
        cache: any CacheStore,{{#has_network}}
        apiClient: any APIClient,{{/has_network}}
        logger: any Logger
    ) -> {{name.pascalCase()}}ViewModel {
        {{#has_network}}let repository = {{name.pascalCase()}}RepositoryImpl(cache: cache, apiClient: apiClient, logger: logger){{/has_network}}{{^has_network}}let repository = {{name.pascalCase()}}RepositoryImpl(cache: cache, logger: logger){{/has_network}}
        return {{name.pascalCase()}}ViewModel(repository: repository)
    }
}
