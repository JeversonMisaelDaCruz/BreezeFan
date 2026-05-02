import SwiftUI

/// One preset button. Mirrors `PresetBtn` in the JSX (atoms.jsx).
struct PresetButton: View {
    let preset: Preset
    let isActive: Bool
    let action: () -> Void
    @Environment(AppState.self) private var appState
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(preset.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? appState.accentColor : FCTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.displayName) preset")
        .accessibilityValue(isActive ? "selected" : "")
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private var background: Color {
        if isActive { return appState.accentColor.opacity(0.15) }
        if hovered  { return Color.white.opacity(0.05) }
        return Color.white.opacity(0.03)
    }

    private var border: Color {
        if isActive { return appState.accentColor.opacity(0.50) }
        return Color.white.opacity(0.06)
    }
}
