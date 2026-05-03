import SwiftUI
import AppKit

/// Animated radial RPM/temp ring. Mirrors the SVG `FCDial` from
/// `~/Downloads/FanControl/app/atoms.jsx`.
///
/// > **NOT USED BY THE MVP LAYOUT.** This primitive is reserved for the
/// > alternative layouts `~/Downloads/FanControl/app/main-pulse.jsx` and
/// > `~/Downloads/FanControl/app/main-spectrum.jsx` (future ports).
/// > The MVP fan row uses a simple disc + linear progress bar (`GlassFanRow`
/// > in `App/Views/FanRow.swift`) — see change `fix-liquid-glass-fidelity`
/// > for the audit that reverted the previous misuse of `FCDial` in the MVP.
///
/// - Track arc: full circle, stroke `stroke` pt, color white@10%
/// - Value arc: arc from 0° to `(value/max) * 360°`, stroke `stroke` pt, color `accent`
///   (or `FCTheme.danger` when `warning=true`)
/// - Center: optional content (e.g. label/sub Text or rotating fan icon)
/// - Animation: easeOut ~500ms when value changes, respects Reduce Motion
struct FCDial<Center: View>: View {
    let value: Double
    let max: Double
    let accent: Color
    let size: CGFloat
    let stroke: CGFloat
    let warning: Bool
    let center: Center

    @State private var reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    init(
        value: Double,
        max: Double,
        accent: Color = FCTheme.accentBlue,
        size: CGFloat = 96,
        stroke: CGFloat = 6,
        warning: Bool = false,
        @ViewBuilder center: () -> Center
    ) {
        self.value = value
        self.max = max
        self.accent = accent
        self.size = size
        self.stroke = stroke
        self.warning = warning
        self.center = center()
    }

    private var clampedFraction: Double {
        guard max > 0 else { return 0 }
        return Swift.max(0, Swift.min(1, value / max))
    }

    private var ringColor: Color {
        warning ? FCTheme.danger : accent
    }

    var body: some View {
        ZStack {
            // Track (full circle, dim white)
            Circle()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            // Value arc (start at top, sweep clockwise)
            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.5), value: clampedFraction)

            // Center content
            center
        }
        .frame(width: size, height: size)
        .onReceive(NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )) { _ in
            reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    }
}

extension FCDial where Center == EmptyView {
    init(
        value: Double,
        max: Double,
        accent: Color = FCTheme.accentBlue,
        size: CGFloat = 96,
        stroke: CGFloat = 6,
        warning: Bool = false
    ) {
        self.init(value: value, max: max, accent: accent, size: size, stroke: stroke, warning: warning) {
            EmptyView()
        }
    }
}
