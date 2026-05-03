import SwiftUI
import AppKit

/// Root window container — minimalist dark.
///
/// History: previous iterations attempted to port the JSX Liquid Glass mockup
/// (`~/Downloads/FanControl/app/window-shell.jsx`) with a colorful wallpaper
/// + multi-layer glass + custom traffic lights. The result kept being visually
/// off and the custom dots ended up out-of-place. User feedback was final:
/// "ainda nao parece nada com liquid glass, se nao foi conseguir implementar
///  so deixe minimalista preto".
///
/// Current setup:
/// - Native macOS titlebar (default `.titleBar` window style) — system draws
///   the traffic lights in their correct OS position.
/// - Solid dark background `FCTheme.bgGraphiteBottom` — graphite-near-black.
/// - Body content sits directly on the dark bg; cards are subtle elevated
///   surfaces (see `FCGlassSurface`).
struct FCWindow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: 360, height: 640)
            .background(FCTheme.bgGraphiteBottom)
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
