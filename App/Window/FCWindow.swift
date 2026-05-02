import SwiftUI

/// Root window container. Replicates `FanControl/app/window-shell.jsx FCWindow`.
///
/// Layers, bottom-up:
/// 1. Linear gradient graphite (top→bottom)
/// 2. Radial gradient accent glow at the top center
/// 3. Subtle grain overlay (omitted in MVP — SVG noise pattern)
/// 4. Content
/// 5. Traffic lights pinned top-left
struct FCWindow<Content: View>: View {
    let content: Content
    @Environment(AppState.self) private var appState

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: graphite linear gradient
            LinearGradient(
                colors: [FCTheme.bgGraphiteTop, FCTheme.bgGraphiteBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 2: accent glow radial gradient at top
            RadialGradient(
                gradient: Gradient(colors: [
                    appState.accentColor.opacity(0.18),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.5, y: -0.10),
                startRadius: 0,
                endRadius: 280
            )
            .allowsHitTesting(false)

            // Layer 3: content
            content
                .padding(.top, 28) // leave space for traffic lights
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Layer 4: traffic lights overlay top-left
            FCTrafficLights()
                .padding(.leading, 14)
                .padding(.top, 14)
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 24)
    }
}

#if DEBUG
#Preview {
    FCWindow {
        VStack {
            Spacer()
            Text("Preview")
                .foregroundStyle(FCTheme.textPrimary)
            Spacer()
        }
    }
    .environment(AppState.preview)
}
#endif
