import SwiftUI

/// Decorative traffic-light dots. Mirrors `BreezeFan/app/window-shell.jsx FCTrafficLights`.
/// Decorative only — clicks do nothing. Window close/minimize is handled via menu/cmd shortcuts.
struct FCTrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            dot(color: FCTheme.trafficRed)
                .accessibilityHidden(true)
            dot(color: FCTheme.trafficYellow)
                .accessibilityHidden(true)
            dot(color: FCTheme.trafficGreen)
                .accessibilityHidden(true)
        }
    }

    private func dot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5)
            )
    }
}

#if DEBUG
#Preview {
    FCTrafficLights()
        .padding(20)
        .background(FCTheme.bgGraphiteBottom)
}
#endif
