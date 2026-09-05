import Platform

/// The Scanner feature's composition seam — the **only** place `Data` →
/// `Domain` → `Presentation` are wired together.
///
/// It lives at the package root, outside `Data/` · `Domain/` · `Presentation/`,
/// on purpose (mirrors `SettingsFeatureModule`): it is the one file allowed to
/// name the `internal` `Data` type `ScannerRepositoryImpl` while still being
/// `public` for the `App` composition root (Task 12) to call.
///
/// The Scanner stub has no dependencies to inject — no cache, no logger, no
/// network — so the factories take no parameters.
public enum ScannerModule {
    /// Builds a ready-to-register `ScannerRouteProvider`. A fresh
    /// `ScannerViewModel` (over a `ScannerRepositoryImpl`) is created per
    /// navigation.
    @MainActor
    public static func makeRouteProvider() -> ScannerRouteProvider {
        ScannerRouteProvider {
            ScannerViewModel(repository: ScannerRepositoryImpl())
        }
    }

    /// Builds a `ScannerViewModel` directly, for a host that manages its own
    /// navigation.
    @MainActor
    public static func makeViewModel() -> ScannerViewModel {
        ScannerViewModel(repository: ScannerRepositoryImpl())
    }
}
