import SwiftUI
import AppKit

/// One fan row inside the Fans card. Mirrors JSX `GlassFanRow`
/// (`~/Downloads/FanControl/app/main-mvp.jsx:100-145`):
///
///   ┌─────┐  Left Fan ........... 4,280 RPM
///   │ ⚙ │  ━━━━━━━━━━━━━━━━━━━━━━━░░  66%
///   └─────┘
///
///   - 30×30 round glass disc with the spinning fan glyph (14pt).
///   - Centre column: top row [label / RPM tabular], then 5pt linear glass
///     progress bar (accent gradient + glow).
///   - Right column: 38pt fixed width, duty% in tabular nums @0.65 opacity.
///
/// Note: this row does **not** use `FCDial` — the radial primitive is reserved
/// for `main-pulse.jsx` / `main-spectrum.jsx` future ports.
/// See change `fix-liquid-glass-fidelity` for context.
struct FanRow: View {
    let label: String
    let rpm: Int?
    let duty: Double?
    let maxRPM: Int

    @Environment(AppState.self) private var appState

    private var pct: Double {
        guard let rpm, maxRPM > 0 else { return 0 }
        return min(1.0, Double(rpm) / Double(maxRPM))
    }

    /// JSX: `Math.max(0.5, 3 - duty * 2.5)` seconds per rotation.
    private var spinDuration: Double? {
        guard let d = duty, d > 0 else { return nil }
        return max(0.5, 3.0 - d * 2.5)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            glassDisc

            VStack(alignment: .leading, spacing: 5) {
                // Top row: label / RPM
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(rpmDisplay)
                            .font(.system(size: 12, weight: .medium))
                            .fcTabularNums()
                            .foregroundStyle(Color.white)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.1), value: rpm ?? 0)
                        Text("RPM")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }

                progressTrack
            }

            Text(dutyDisplay)
                .font(.system(size: 11))
                .fcTabularNums()
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: - 30×30 glass disc with spinning fan glyph

    private var glassDisc: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )

            FanGlyph(spinDuration: spinDuration)
                .frame(width: 14, height: 14)
        }
        .frame(width: 28, height: 28)
    }

    // MARK: - 5pt linear glass progress bar

    private var progressTrack: some View {
        GeometryReader { geo in
            let accent = appState.accentColor
            let fillW = max(0, min(geo.size.width, geo.size.width * pct))

            ZStack(alignment: .leading) {
                // Track: dark recess + hairline
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                // Fill: solid accent
                if fillW > 0 {
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(accent)
                        .frame(width: fillW)
                        .animation(.easeInOut(duration: 0.6), value: fillW)
                }
            }
        }
        .frame(height: 4)
    }

    // MARK: - Formatting

    private var rpmDisplay: String {
        guard let rpm else { return "—" }
        return FanRow.rpmFormatter.string(from: NSNumber(value: rpm)) ?? "\(rpm)"
    }

    private var dutyDisplay: String {
        guard let d = duty else { return "—" }
        return "\(Int((d * 100).rounded()))%"
    }

    /// Shared RPM formatter — single allocation per process lifetime.
    /// SwiftUI bodies recompute frequently; a fresh NumberFormatter per render
    /// was a measurable allocation source.
    private static let rpmFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
}

/// Spinning fan icon.
///
/// When `spinDuration` is `nil` (fan stopped) the view falls back to a static
/// `Image` — no `TimelineView`, no per-frame redraw. When spinning, we use a
/// `TimelineView(.animation)` so duty changes can adjust speed without cancelling
/// the running animation. The fan glyph is decorative — capping the frame budget
/// matters when both fans + the menu bar icon also redraw.
struct FanGlyph: View {
    let spinDuration: Double?

    var body: some View {
        if let dur = spinDuration, dur > 0 {
            TimelineView(.animation) { context in
                Image(systemName: "fan.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white)
                    .rotationEffect(.degrees(Self.angle(at: context.date, duration: dur)))
            }
        } else {
            Image(systemName: "fan.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
        }
    }

    @inline(__always)
    private static func angle(at date: Date, duration: Double) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
        return (elapsed * 360.0 / duration).truncatingRemainder(dividingBy: 360.0)
    }
}
