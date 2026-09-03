import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public extension Color {
    /// Brand primary — call-to-action surfaces.
    static var appPrimary: Color {
        dynamic(AppColor.primary)
    }

    /// Secondary accent.
    static var appSecondary: Color {
        dynamic(AppColor.secondary)
    }

    /// Destructive / danger.
    static var appDestructive: Color {
        dynamic(AppColor.destructive)
    }

    /// Screen background.
    static var appBackground: Color {
        dynamic(AppColor.background)
    }

    /// Raised surface (cards, fields).
    static var appSurface: Color {
        dynamic(AppColor.surface)
    }

    /// Primary text / foreground on `appBackground`.
    static var appTextPrimary: Color {
        dynamic(AppColor.textPrimary)
    }

    /// Secondary / muted text.
    static var appTextSecondary: Color {
        dynamic(AppColor.textSecondary)
    }

    /// Builds a `Color` that resolves `token`'s light / dark hex against the
    /// active interface style. Falls back to the light value where no platform
    /// appearance API is available (non-Apple hosts).
    static func dynamic(_ token: AppColor) -> Color {
        let lightColor = Color(hex: token.lightHex) ?? .clear
        let darkColor = Color(hex: token.darkHex) ?? .clear
        #if canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
            })
        #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return isDark ? NSColor(darkColor) : NSColor(lightColor)
            })
        #else
            return lightColor
        #endif
    }
}
