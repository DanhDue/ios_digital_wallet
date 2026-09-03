import SwiftUI

/// The type scale. Thin wrappers over Dynamic Type text styles so components
/// never hard-code point sizes.
public enum AppFont {
    /// Large screen title.
    public static let largeTitle: Font = .largeTitle.weight(.bold)
    /// Section title.
    public static let title: Font = .title2.weight(.semibold)
    /// Emphasis / row heading.
    public static let headline: Font = .headline
    /// Default body copy.
    public static let body: Font = .body
    /// Secondary / supporting copy.
    public static let subheadline: Font = .subheadline
    /// Smallest supported label.
    public static let caption: Font = .caption
    /// Button label.
    public static let button: Font = .body.weight(.semibold)
}
