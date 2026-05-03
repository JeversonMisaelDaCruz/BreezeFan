import SwiftUI

/// Mesh gradient backdrop sitting beneath all `FCGlassSurface` layers — gives the
/// glass something colorful to refract. Mirrors the CSS multi-radial gradient in
/// `~/Downloads/FanControl/app/window-shell.jsx FCWallpaper`.
///
/// Stops:
///   1. Top-right (80%, 15%): accent tint @85% opacity, radius 60×50
///   2. Bottom-left (15%, 80%): magenta `#d946ef`
///   3. Bottom-right (85%, 90%): cyan `#06b6d4`
///   4. Top-mid (30%, 20%): indigo `#6366f1`
///   5. Base diagonal: `#1e1b4b → #0c0a1f`
struct FCWallpaper: View {
    let accent: Color

    init(accent: Color = FCTheme.accentBlue) {
        self.accent = accent
    }

    var body: some View {
        ZStack {
            // Base linear (160°)
            LinearGradient(
                colors: [Color(hex: "#1e1b4b"), Color(hex: "#0c0a1f")],
                startPoint: UnitPoint(x: 0.15, y: 0),
                endPoint: UnitPoint(x: 0.85, y: 1)
            )

            // Indigo blob (30%, 20%) — large
            radialBlob(color: Color(hex: "#6366f1"), at: UnitPoint(x: 0.30, y: 0.20),
                       widthRatio: 0.70, heightRatio: 0.50, opacity: 0.65)

            // Cyan (85%, 90%) — small
            radialBlob(color: Color(hex: "#06b6d4"), at: UnitPoint(x: 0.85, y: 0.90),
                       widthRatio: 0.45, heightRatio: 0.35, opacity: 0.85)

            // Magenta (15%, 80%) — medium
            radialBlob(color: Color(hex: "#d946ef"), at: UnitPoint(x: 0.15, y: 0.80),
                       widthRatio: 0.50, heightRatio: 0.40, opacity: 0.75)

            // Accent (80%, 15%) — main, tied to user's accent setting
            radialBlob(color: accent, at: UnitPoint(x: 0.80, y: 0.15),
                       widthRatio: 0.60, heightRatio: 0.50, opacity: 0.85)
        }
        .saturation(1.15)
    }

    /// Helper: radial gradient confined to a portion of the parent, centered at `point`.
    @ViewBuilder
    private func radialBlob(
        color: Color,
        at point: UnitPoint,
        widthRatio: CGFloat,
        heightRatio: CGFloat,
        opacity: Double
    ) -> some View {
        GeometryReader { geo in
            let w = geo.size.width * widthRatio
            let h = geo.size.height * heightRatio
            RadialGradient(
                gradient: Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                center: .center,
                startRadius: 0,
                endRadius: max(w, h)
            )
            .frame(width: w * 2, height: h * 2)
            .position(
                x: geo.size.width * point.x,
                y: geo.size.height * point.y
            )
        }
    }
}
