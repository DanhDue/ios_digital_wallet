import SwiftUI

/// A light / dark theme descriptor. The design system resolves colors per
/// appearance automatically (see `Color.dynamic(_:)`); `AppTheme` exists for the
/// rare call site that needs the concrete palette for one appearance — e.g. a
/// snapshot test or a preview pinned to one mode.
public struct AppTheme: Equatable, Sendable {
    /// The appearance this theme describes.
    public let colorScheme: ColorScheme

    public init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }

    /// The light palette.
    public static let light = AppTheme(colorScheme: .light)
    /// The dark palette.
    public static let dark = AppTheme(colorScheme: .dark)

    /// The resolved hex for `token` in this theme.
    public func hex(_ token: AppColor) -> String {
        token.hex(for: colorScheme)
    }

    /// The resolved `Color` for `token` in this theme.
    public func color(_ token: AppColor) -> Color {
        token.color(for: colorScheme)
    }
}
