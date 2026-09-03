/// Namespace of route values shared *between* features.
///
/// A feature navigates to another feature's entry point through one of these —
/// e.g. `appRouter.navigate(to: AppRoutes.SettingsRoot())` — without importing
/// that feature. Feature-private destinations are declared inside the feature.
public enum AppRoutes {
    /// Entry point of the Settings feature.
    public struct SettingsRoot: AppRoute {
        public init() {}
    }

    /// Entry point of the Scanner feature.
    public struct ScannerRoot: AppRoute {
        public init() {}
    }
}
