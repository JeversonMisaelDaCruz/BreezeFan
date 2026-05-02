import SwiftUI

/// Root window container. Background graphite + accent glow.
/// Traffic lights are the macOS native ones (functional close/min/zoom) — we don't draw decorative ones.
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

            // Layer 3: content (top padding leaves room for native traffic lights)
            content
                .padding(.top, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 360, height: 640)
    }
}

#if DEBUG
#Preview {
    FCWindow {
        VStack {
            Spacer()
            Text("Preview").foregroundStyle(FCTheme.textPrimary)
            Spacer()
        }
    }
    .environment(AppState.preview)
}
#endif
