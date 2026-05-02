import SwiftUI

extension Color {
    /// Hex constructor: `Color(hex: "#1a1c20")` or `Color(hex: "1a1c20")`.
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >>  8) / 255.0
        let b = Double( rgb & 0x0000FF       ) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Theme tokens. Mirrors `FanControl/app/window-shell.jsx` palette.
public enum FCTheme {
    public static let accentBlue   = Color(hex: "#3b82f6")
    public static let accentPurple = Color(hex: "#a855f7")
    public static let bgGraphiteTop    = Color(hex: "#1a1c20")
    public static let bgGraphiteBottom = Color(hex: "#0f1013")

    public static let trafficRed    = Color(hex: "#ff5f57")
    public static let trafficYellow = Color(hex: "#febc2e")
    public static let trafficGreen  = Color(hex: "#28c840")

    public static let divider     = Color.white.opacity(0.06)
    public static let textPrimary = Color.white.opacity(0.92)
    public static let textMuted   = Color.white.opacity(0.55)
    public static let textGhost   = Color.white.opacity(0.35)

    public static let danger = Color(hex: "#ef4444")
    public static let good   = Color(hex: "#10b981")
    public static let warn   = Color(hex: "#f59e0b")
}
