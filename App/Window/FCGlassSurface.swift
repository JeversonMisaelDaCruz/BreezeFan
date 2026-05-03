import SwiftUI
import AppKit

/// Card surface primitive — minimalist dark.
///
/// The name "GlassSurface" is preserved for API stability with the rest of
/// the codebase, but this is no longer a Liquid Glass primitive. After two
/// failed attempts at a faithful CSS-`backdrop-filter` port, user pivoted
/// to a minimalist black aesthetic ("se nao foi conseguir implementar
/// liquid glass, so deixe minimalista preto").
///
/// What it does now:
///   - Solid elevated dark fill (`#16181c`) on top of the window's
///     graphite-bottom bg (`#0f1013`).
///   - Single hairline white border at 6% opacity (0.5pt).
///   - No blur, no sheen, no gradient, no inner shadows.
///
/// `intensity` and `sheen` parameters are accepted for source compatibility
/// with existing call sites but are ignored by this implementation.
struct FCGlassSurface<Content: View>: View {
    let radius: CGFloat
    let intensity: Double
    let sheen: Bool
    let content: Content

    init(
        radius: CGFloat = FCRadius.window,
        intensity: Double = 1.0,
        sheen: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.intensity = intensity
        self.sheen = sheen
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(FCTheme.cardSurface)

            content
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}
