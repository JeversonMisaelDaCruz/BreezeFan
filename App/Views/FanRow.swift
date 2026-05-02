import SwiftUI

/// One fan listed in the Fans section. Mirrors `FCFanRow` from `atoms.jsx`.
struct FanRow: View {
    let label: String
    let rpm: Int?
    let duty: Double?

    /// Spin animation speed in seconds per revolution. duty=0 -> stop; duty=1 -> 0.5s/rev.
    private var spinDuration: Double? {
        guard let d = duty, d > 0 else { return nil }
        return max(0.4, 3.0 - d * 2.5)
    }

    var body: some View {
        HStack(spacing: 12) {
            FanGlyph(spinDuration: spinDuration)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FCFont.body)
                    .foregroundStyle(FCTheme.textPrimary)
                RPMBar(duty: duty)
                    .frame(height: 3)
                    .frame(maxWidth: 160)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(rpmDisplay)
                    .font(FCFont.mono)
                    .fcTabularNums()
                    .foregroundStyle(FCTheme.textPrimary)
                Text(dutyDisplay)
                    .font(FCFont.mono)
                    .fcTabularNums()
                    .foregroundStyle(FCTheme.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    private var rpmDisplay: String {
        guard let rpm else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let value = formatter.string(from: NSNumber(value: rpm)) ?? "\(rpm)"
        return "\(value) RPM"
    }

    private var dutyDisplay: String {
        guard let d = duty else { return "—" }
        return "\(Int((d * 100).rounded()))%"
    }
}

/// Mini horizontal bar showing the duty as a fill percentage.
struct RPMBar: View {
    let duty: Double?
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.05))
                if let d = duty {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(appState.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(max(d, 0), 1)))
                }
            }
        }
    }
}

/// Spinning fan icon. Uses `TimelineView(.animation)` driven by absolute time so
/// duty changes adjust the rotation speed without cancelling the running animation.
struct FanGlyph: View {
    let spinDuration: Double?
    private static let referenceDate = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        TimelineView(.animation) { context in
            let angle = computeAngle(at: context.date)
            Image(systemName: "fan.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(FCTheme.textMuted)
                .rotationEffect(.degrees(angle))
        }
    }

    /// Maps an absolute timestamp + spin duration to a rotation angle.
    /// When `spinDuration` is nil or the duty is zero, the icon stays at 0°.
    private func computeAngle(at date: Date) -> Double {
        guard let dur = spinDuration, dur > 0 else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate
        return (elapsed * 360.0 / dur).truncatingRemainder(dividingBy: 360.0)
    }
}
