import Core
import SwiftUI

/// Slang-like strongly-typed hierarchical localization accessor for SwiftUI.
///
/// Resolves strings dynamically through `LocalizationService` (`AppLocalizationManager`),
/// maintaining complete support for dynamic OTA server overrides, String Catalog (`Localizable.xcstrings`),
/// and fallback defaults without exposing raw magic strings to SwiftUI views.
///
/// All feature namespaces (`t.settings.*`, `t.scanner.*`, `t.shell.*`, etc.) are
/// automatically generated into `Translations.generated.swift` from each module's
/// `Localizable.xcstrings` via `./scripts/merge_localizations.py`.
///
/// Example:
/// ```swift
/// // Using global accessor:
/// Text(t.settings.account.changePassword)
///
/// // Or using SwiftUI Environment:
/// @Environment(\.t) private var t: Translations
/// SettingsItemRow(title: t.settings.account.changePassword)
/// ```
@MainActor
public struct Translations {
    public let manager: any LocalizationService

    public init(manager: any LocalizationService = AppLocalizationManager.shared) {
        self.manager = manager
    }

    public static var current: Translations {
        Translations(manager: AppLocalizationManager.shared)
    }

    /// Dynamic fallback lookup via `callAsFunction`.
    ///
    /// Example: `t("custom.key", default: "Fallback")`
    public func callAsFunction(_ key: String, default defaultString: String? = nil) -> String {
        manager.translate(key, default: defaultString)
    }

    public func translate(_ key: String, default defaultString: String? = nil) -> String {
        manager.translate(key, default: defaultString)
    }
}

// MARK: - Global & Environment Accessors

/// Global convenience accessor matching Slang's `t`.
@MainActor
public var t: Translations {
    Translations.current
}

/// Global self-documenting accessor for translations.
@MainActor
public var translations: Translations {
    Translations.current
}

/// Global standard iOS localization shorthand.
@MainActor
public var l10n: Translations {
    Translations.current
}

public extension EnvironmentValues {
    /// Slang-style shorthand environment accessor
    @Entry var t: Translations = MainActor.assumeIsolated {
        Translations.current
    }

    /// Explicit self-documenting environment accessor
    @Entry var translations: Translations = MainActor.assumeIsolated {
        Translations.current
    }

    /// Standard iOS localization environment accessor
    @Entry var l10n: Translations = MainActor.assumeIsolated {
        Translations.current
    }
}
