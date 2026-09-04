import Core
import SwiftUI

/// Manages the application-wide theme appearance mode (system, light, dark).
///
/// Backed by a `Core.CacheStore` for persistent local storage, and publishes
/// changes to `AppEventBus` so cross-module consumers can react.
@MainActor
public final class AppThemeManager: ObservableObject {
    public static let storageKey = "app_theme_mode"

    @Published public private(set) var mode: AppThemeMode

    private let cache: any CacheStore
    private let eventBus: AppEventBus

    public init(cache: any CacheStore, eventBus: AppEventBus) {
        self.cache = cache
        self.eventBus = eventBus

        if let raw = cache.get(String.self, key: Self.storageKey), let restored = AppThemeMode(rawValue: raw) {
            mode = restored
        } else {
            mode = .system
        }
    }

    /// The SwiftUI `ColorScheme` corresponding to the active mode.
    /// Returns `nil` for `.system` so SwiftUI follows the operating system appearance.
    public var colorScheme: ColorScheme? {
        switch mode {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// Sets the active appearance mode and persists the choice.
    public func setMode(_ newMode: AppThemeMode) {
        guard newMode != mode else { return }
        mode = newMode
        cache.set(newMode.rawValue, key: Self.storageKey)
        eventBus.publish(ThemeModeChanged(mode: newMode))
    }
}
