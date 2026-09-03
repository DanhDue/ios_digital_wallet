import SwiftUI

/// Semantic color tokens. Each token carries an explicit light and dark hex so
/// the values can be asserted exactly in tests without `UIColor` / `NSColor` on
/// the test host, and so the palette is documented in one place. `color(for:)`
/// resolves a token to a `SwiftUI.Color`; `Color.app*` (see `Color+Semantic`)
/// wraps the pair in a single appearance-reactive color for view code.
public enum AppColor: String, CaseIterable, Sendable {
    /// Brand primary — primary call-to-action.
    case primary
    /// Secondary accent / muted control.
    case secondary
    /// Destructive / danger.
    case destructive
    /// Screen background.
    case background
    /// Raised surface — cards, text fields.
    case surface
    /// Primary text / foreground.
    case textPrimary
    /// Secondary / supporting text.
    case textSecondary

    /// Hex value in light appearance (`#RRGGBB`).
    public var lightHex: String {
        switch self {
        case .primary: "#0B5FFF"
        case .secondary: "#5A6472"
        case .destructive: "#D7263D"
        case .background: "#FFFFFF"
        case .surface: "#F2F3F5"
        case .textPrimary: "#11181C"
        case .textSecondary: "#5A6472"
        }
    }

    /// Hex value in dark appearance (`#RRGGBB`).
    public var darkHex: String {
        switch self {
        case .primary: "#4C8DFF"
        case .secondary: "#9AA4B2"
        case .destructive: "#FF5A5F"
        case .background: "#0B0B0F"
        case .surface: "#1C1C22"
        case .textPrimary: "#F5F7FA"
        case .textSecondary: "#A7B0BA"
        }
    }

    /// The hex value for `scheme`.
    public func hex(for scheme: ColorScheme) -> String {
        scheme == .dark ? darkHex : lightHex
    }

    /// The resolved `Color` for `scheme`. The documented hexes always parse, so
    /// the `.clear` fallback is unreachable in practice.
    public func color(for scheme: ColorScheme) -> Color {
        Color(hex: hex(for: scheme)) ?? .clear
    }
}
