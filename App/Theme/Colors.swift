import SwiftUI

extension Color {
    /// Hex constructor: `Color(hex: "#1a1c20")` or `Color(hex: "1a1c20")`.
    ///
    /// Hand-rolled parser that walks `utf8` bytes directly — no `Scanner`,
    /// no `String.replacingOccurrences` allocation. Static color tokens use
    /// this once at module load; hot-path call sites benefit even more.
    init(hex: String, opacity: Double = 1.0) {
        var rgb: UInt32 = 0
        for byte in hex.utf8 {
            let nibble: UInt32
            switch byte {
            case 0x30...0x39: nibble = UInt32(byte &- 0x30)          // '0'..'9'
            case 0x41...0x46: nibble = UInt32(byte &- 0x41 &+ 10)    // 'A'..'F'
            case 0x61...0x66: nibble = UInt32(byte &- 0x61 &+ 10)    // 'a'..'f'
            case 0x23: continue                                       // '#'
            default: continue                                          // skip junk
            }
            rgb = (rgb << 4) | nibble
        }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >>  8) / 255.0
        let b = Double( rgb & 0x0000FF       ) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Theme tokens. Mirrors `BreezeFan/app/window-shell.jsx` palette.
public enum FCTheme {
    public static let accentBlue   = Color(hex: "#3b82f6")
    public static let accentPurple = Color(hex: "#a855f7")
    public static let bgGraphiteTop    = Color(hex: "#1a1c20")
    public static let bgGraphiteBottom = Color(hex: "#0f1013")

    /// Elevated card surface on top of `bgGraphiteBottom`. Used by
    /// `FCGlassSurface` after the minimalist-dark pivot.
    public static let cardSurface = Color(hex: "#16181c")

    public static let trafficRed    = Color(hex: "#ff5f57")
    public static let trafficYellow = Color(hex: "#febc2e")
    public static let trafficGreen  = Color(hex: "#28c840")

    // Specular highlight ("glow") for each traffic light's radial gradient.
    // Mirrors JSX `~/Downloads/FanControl/app/window-shell.jsx:18-20`.
    public static let trafficRedGlow    = Color(hex: "#ff8c83")
    public static let trafficYellowGlow = Color(hex: "#ffd56a")
    public static let trafficGreenGlow  = Color(hex: "#5cdf68")

    public static let divider     = Color.white.opacity(0.06)
    public static let textPrimary = Color.white.opacity(0.92)
    public static let textMuted   = Color.white.opacity(0.55)
    public static let textGhost   = Color.white.opacity(0.35)

    public static let danger = Color(hex: "#ef4444")
    public static let good   = Color(hex: "#10b981")
    public static let warn   = Color(hex: "#f59e0b")

    /// Hero status dot colors — green (cool), amber (warming), red (hot). These
    /// are accessed inside `MainView.statusDotColor` which runs on every body
    /// invocation; staticizing them avoids re-parsing the hex literal per render.
    public static let statusGreen = Color(hex: "#22c55e")
    public static let statusAmber = Color(hex: "#f59e0b")

    /// Wallpaper mesh-gradient stops. Used by `FCWallpaper.body` — caching
    /// avoids 4 hex parses per redraw of the window backdrop.
    public static let wallpaperBaseTop    = Color(hex: "#1e1b4b")
    public static let wallpaperBaseBottom = Color(hex: "#0c0a1f")
    public static let wallpaperIndigo     = Color(hex: "#6366f1")
    public static let wallpaperCyan       = Color(hex: "#06b6d4")
    public static let wallpaperMagenta    = Color(hex: "#d946ef")
}
