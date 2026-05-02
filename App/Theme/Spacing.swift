import CoreGraphics

/// Spacing tokens. All padding, gap, and inset values in the app should reference these
/// tokens — no magic numbers like 12, 14, 18 etc. Mirrors the JSX design system.
public enum FCSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}
