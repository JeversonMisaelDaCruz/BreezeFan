import SwiftUI

/// One preset button. Mirrors `PresetBtn` in the JSX (atoms.jsx).
/// Hover and active state changes animated with FCAnimation.fast / .normal.
struct PresetButton: View {
    let preset: Preset
    let isActive: Bool
    let action: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(preset.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? appState.accentColor : FCTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FCSpacing.md)
            .padding(.vertical, FCSpacing.sm + 2)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.displayName) preset")
        .accessibilityValue(isActive ? "selected" : "")
        .onHover { newValue in
            hovered = newValue
            if isEnabled {
                if newValue {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
        .animation(FCAnimation.fast, value: hovered)
        .animation(FCAnimation.normal, value: isActive)
    }

    private var background: Color {
        if isActive { return appState.accentColor.opacity(0.15) }
        if hovered && isEnabled { return Color.white.opacity(0.07) }
        return Color.white.opacity(0.03)
    }

    private var border: Color {
        if isActive { return appState.accentColor.opacity(0.50) }
        if hovered && isEnabled { return Color.white.opacity(0.10) }
        return Color.white.opacity(0.06)
    }
}
