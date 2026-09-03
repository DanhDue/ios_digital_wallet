import CoreGraphics

/// The 8pt-grid spacing scale. Plain value-type tokens — zero overhead, no theme
/// environment object. Referenced everywhere instead of hard-coded padding.
public enum AppSpacing {
    // swiftlint:disable identifier_name
    /// Extra-small — 4pt.
    public static let xs: CGFloat = 4
    /// Small — 8pt.
    public static let sm: CGFloat = 8
    /// Medium — 16pt (the default gutter).
    public static let md: CGFloat = 16
    /// Large — 24pt.
    public static let lg: CGFloat = 24
    /// Extra-large — 32pt.
    public static let xl: CGFloat = 32
    // swiftlint:enable identifier_name
}
