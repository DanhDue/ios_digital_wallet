import Core

/// The Settings feature's composition root — the **only** place `Data` →
/// `Domain` → `Presentation` are wired together.
///
/// It lives at the package root, outside `Data/` · `Domain/` · `Presentation/`,
/// on purpose: ArchTests K2/K3/K4 scan those folders, and only this file is
/// allowed to name the `internal` `Data` type `SettingsRepositoryImpl` while
/// still being `public` for the `App` composition root (Task 12) to call.
public enum SettingsModule {
    /// Builds a ready-to-register `SettingsRouteProvider`. A fresh
    /// `SettingsViewModel` (with a `SettingsRepositoryImpl` over `cache`) is
    /// created per navigation.
    ///
    /// - Parameters:
    ///   - cache: where the `"settings"` slot is persisted.
    ///   - logger: sink for the "using defaults" fallback line.
    @MainActor
    public static func makeRouteProvider(
        cache: any CacheStore,
        logger: any Logger
    ) -> SettingsRouteProvider {
        SettingsRouteProvider {
            SettingsViewModel(repository: SettingsRepositoryImpl(cache: cache, logger: logger))
        }
    }

    /// Builds a `SettingsViewModel` directly, for a host that manages its own
    /// navigation.
    @MainActor
    public static func makeViewModel(
        cache: any CacheStore,
        logger: any Logger
    ) -> SettingsViewModel {
        SettingsViewModel(repository: SettingsRepositoryImpl(cache: cache, logger: logger))
    }
}
