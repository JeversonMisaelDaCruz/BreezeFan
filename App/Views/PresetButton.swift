import SwiftUI

/// One preset chip in the Mode card. Mirrors JSX `PresetGlass`
/// (`~/Downloads/FanControl/app/main-mvp.jsx:148-189`):
///
///   - Container: `RoundedRectangle(cornerRadius: 12)`, padding "10 8".
///   - Inactive: white@6% fill + inset white@12% stroke + top sheen @18%.
///   - Active:   accent gradient (0.45 → 0.25 top-bottom) + bottom glow
///               (`shadow(accent@35%, radius: 7, y: 4)`) + accent inset stroke @70%
///               + top white highlight @35%.
///   - Vertical stack: SF Symbol glyph (16pt) above label (11pt).
struct PresetButton: View {
    let preset: Preset
    let isActive: Bool
    let action: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    private var accent: Color { appState.accentColor }
    private var glyphColor: Color { isActive ? .white : .white.opacity(0.7) }
    private var labelColor: Color { isActive ? .white : .white.opacity(0.8) }
    private var labelWeight: Font.Weight { isActive ? .semibold : .medium }

    var body: some View {
        Button(action: action) {
            ZStack {
                background

                // Glyph + label, vertical stack, gap 5pt.
                VStack(spacing: 5) {
                    PresetIcon(kind: preset.iconKind, color: glyphColor)
                        .frame(width: 16, height: 16)
                    Text(preset.displayName)
                        .font(.system(size: 11, weight: labelWeight))
                        .foregroundStyle(labelColor)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.displayName) preset")
        .accessibilityValue(isActive ? "selected" : "")
        .onHover { newValue in
            hovered = newValue
            if isEnabled {
                if newValue { NSCursor.pointingHand.set() }
                else { NSCursor.arrow.set() }
            }
        }
        .animation(FCAnimation.fast, value: hovered)
        .animation(FCAnimation.normal, value: isActive)
    }

    // MARK: - Background (active vs inactive)

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if isActive {
            // Solid accent tint + accent hairline. No gradient, no glow.
            shape
                .fill(accent.opacity(0.20))
                .overlay(
                    shape.strokeBorder(accent.opacity(0.55), lineWidth: 0.5)
                )
        } else {
            // Subtle elevated surface + hairline white.
            shape
                .fill(Color.white.opacity(hovered && isEnabled ? 0.06 : 0.04))
                .overlay(
                    shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Preset icon glyph

extension Preset {
    /// Stable identifier for the icon variant (mirrors JSX `icon` field).
    var iconKind: PresetIcon.Kind {
        switch self {
        case .silent:      return .silent
        case .balanced:    return .balanced
        case .performance: return .performance
        case .max:         return .max
        }
    }
}

/// One of four SF-Symbol-equivalent glyphs used by `PresetButton`.
/// Mirrors JSX `PresetIcon` (`main-mvp.jsx:191-200`):
///   - silent      — speaker with sound waves
///   - balanced    — dashed circle with a centred dot
///   - performance — zigzag arrow trending up
///   - max         — lightning bolt
struct PresetIcon: View {
    enum Kind { case silent, balanced, performance, max }

    let kind: Kind
    let color: Color

    var body: some View {
        switch kind {
        case .silent:
            Image(systemName: "speaker.wave.1.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)

        case .balanced:
            // Composition: dashed circle + filled centre dot.
            ZStack {
                Image(systemName: "circle.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }

        case .performance:
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)

        case .max:
            Image(systemName: "bolt.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        }
    }
}
