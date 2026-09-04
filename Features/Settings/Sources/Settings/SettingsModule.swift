import Core
import Network
import Platform

/// The Settings feature's composition root — the **only** place `Data` →
/// `Domain` → `Presentation` are wired together.
///
/// It lives at the package root, outside `Data/` · `Domain/` · `Presentation/`,
/// on purpose: ArchTests K2/K3/K4 scan those folders, and only this file is
/// allowed to name the `internal` `Data` type `SettingsRepositoryImpl` while
/// still being `public` for the `App` composition root (Task 12) to call.
public enum SettingsModule {
    /// Builds a ready-to-register `SettingsRouteProvider`. A fresh
    /// `SettingsViewModel` is created per navigation.
    ///
    /// - Parameters:
    ///   - cache: where the `"settings"` slot is persisted.
    ///   - apiClient: the remote client for translations & preferences.
    ///   - themeManager: app-wide theme mode coordinator.
    ///   - localizationService: app-wide localization coordinator.
    ///   - logger: sink for the "using defaults" fallback line.
    @MainActor
    public static func makeRouteProvider(
        cache: any CacheStore,
        apiClient: (any APIClient)? = nil,
        themeManager: AppThemeManager? = nil,
        localizationService: (any LocalizationService)? = nil,
        logger: any Logger
    ) -> SettingsRouteProvider {
        SettingsRouteProvider {
            makeViewModel(
                cache: cache,
                apiClient: apiClient,
                themeManager: themeManager,
                localizationService: localizationService,
                logger: logger
            )
        }
    }

    /// Builds a `SettingsViewModel` directly, for a host that manages its own
    /// navigation.
    @MainActor
    public static func makeViewModel(
        cache: any CacheStore,
        apiClient: (any APIClient)? = nil,
        themeManager: AppThemeManager? = nil,
        localizationService: (any LocalizationService)? = nil,
        logger: any Logger
    ) -> SettingsViewModel {
        let repository = SettingsRepositoryImpl(
            cache: cache,
            apiClient: apiClient,
            logger: logger
        )
        return SettingsViewModel(
            repository: repository,
            themeManager: themeManager,
            localizationService: localizationService
        )
    }
}
