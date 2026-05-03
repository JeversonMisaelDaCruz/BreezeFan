import SwiftUI
import AppKit

/// Custom traffic lights that replace the native macOS close/minimize/zoom buttons.
/// Mirrors JSX `~/Downloads/FanControl/app/window-shell.jsx:8-23`:
///
///   - 3 dots, 12×12pt each, spacing 8pt between them.
///   - Each dot has a radial-gradient highlight at (35%, 30%) from a brighter
///     "glow" color into the base color, plus an inset top-white highlight
///     (0.5pt @ 50% white) and an outer bottom hairline (0.5pt @ 25% black).
///   - Cluster-level hover reveals SF Symbol glyphs (×, −, +) inside each dot.
///   - Option-hold while hovering swaps the green dot's `+` for a fullscreen icon.
///   - Each dot is a `Button` wired to the active `NSWindow`:
///       red    → performClose
///       yellow → miniaturize
///       green  → zoom (or toggleFullScreen with Option held)
///
/// The native macOS traffic light buttons are hidden by `FCWindow` via
/// `WindowAccessor` so this view fully replaces them.
struct FCTrafficLights: View {
    /// Fallback NSWindow reference captured by `FCWindow`. Used when
    /// `NSApp.keyWindow` is nil (e.g. brief window-creation race).
    let parentWindow: NSWindow?

    @State private var clusterHovered = false
    @State private var optionHeld = false
    @State private var modifierMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            TrafficDot(
                kind: .close,
                base: FCTheme.trafficRed,
                glow: FCTheme.trafficRedGlow,
                clusterHovered: clusterHovered,
                optionHeld: optionHeld,
                action: { perform(.close) }
            )
            TrafficDot(
                kind: .minimize,
                base: FCTheme.trafficYellow,
                glow: FCTheme.trafficYellowGlow,
                clusterHovered: clusterHovered,
                optionHeld: optionHeld,
                action: { perform(.minimize) }
            )
            TrafficDot(
                kind: .zoom,
                base: FCTheme.trafficGreen,
                glow: FCTheme.trafficGreenGlow,
                clusterHovered: clusterHovered,
                optionHeld: optionHeld,
                action: { perform(.zoom) }
            )
        }
        .onHover { hovering in
            clusterHovered = hovering
            if hovering { NSCursor.pointingHand.set() }
            else        { NSCursor.arrow.set() }
        }
        .onAppear {
            // Track Option key for the cluster-hover glyph swap on the green dot.
            modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                optionHeld = event.modifierFlags.contains(.option)
                return event
            }
        }
        .onDisappear {
            if let monitor = modifierMonitor {
                NSEvent.removeMonitor(monitor)
                modifierMonitor = nil
            }
        }
    }

    // MARK: - Action dispatch

    private func resolveWindow() -> NSWindow? {
        NSApp.keyWindow ?? parentWindow ?? NSApp.windows.first(where: { $0.canBecomeKey })
    }

    private func perform(_ action: TrafficDot.Kind) {
        guard let window = resolveWindow() else { return }
        switch action {
        case .close:
            window.performClose(nil)
        case .minimize:
            window.miniaturize(nil)
        case .zoom:
            if NSEvent.modifierFlags.contains(.option) {
                window.toggleFullScreen(nil)
            } else {
                window.zoom(nil)
            }
        }
    }
}

// MARK: - Single dot

private struct TrafficDot: View {
    enum Kind { case close, minimize, zoom }

    let kind: Kind
    let base: Color
    let glow: Color
    let clusterHovered: Bool
    let optionHeld: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 1. Radial-gradient body — JSX line 12: `radial-gradient(circle at 35% 30%, glow 0%, bg 55%, bg 100%)`.
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: glow, location: 0.0),
                                .init(color: base, location: 0.55),
                                .init(color: base, location: 1.0),
                            ],
                            center: UnitPoint(x: 0.35, y: 0.30),
                            startRadius: 0,
                            endRadius: 7
                        )
                    )

                // 2. Inset top white highlight — arc spanning ~75% of the top of the circle.
                //    JSX `inset 0 0.5px 0 rgba(255,255,255,0.5)`.
                Circle()
                    .trim(from: 0.625, to: 0.875)
                    .stroke(Color.white.opacity(0.5),
                            style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // 3. Outer hairline — JSX `0 0 0 0.5px rgba(0,0,0,0.25)`.
                Circle()
                    .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5)

                // 4. Hover glyph — × / − / + (or fullscreen for green+option).
                if clusterHovered {
                    Image(systemName: glyphSymbol)
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 12, height: 12)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.08), value: clusterHovered)
            .animation(.easeOut(duration: 0.08), value: optionHeld)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .focusable(false)
    }

    private var glyphSymbol: String {
        switch kind {
        case .close:    return "xmark"
        case .minimize: return "minus"
        case .zoom:     return optionHeld ? "arrow.up.left.and.arrow.down.right" : "plus"
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .close:    return "Close window"
        case .minimize: return "Minimize window"
        case .zoom:     return "Zoom window"
        }
    }
}

#if DEBUG
#Preview("Resting") {
    FCTrafficLights(parentWindow: nil)
        .padding(20)
        .background(FCTheme.bgGraphiteBottom)
}
#endif
