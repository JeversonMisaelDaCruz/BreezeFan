import SwiftUI

/// Numeric stepper with `-` / value / `+` buttons. Mirrors `NumStepper` in `curve-mvp.jsx`.
struct NumStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String?

    init(value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, suffix: String? = nil) {
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("−") {
                value = max(value - step, range.lowerBound)
            }
            .disabled(value <= range.lowerBound)

            Text(displayValue)
                .font(FCFont.stepperValue)
                .foregroundStyle(FCTheme.textPrimary)
                .fcTabularNums()
                .frame(minWidth: 40)
                .padding(.horizontal, 6)

            stepButton("+") {
                value = min(value + step, range.upperBound)
            }
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Color.black.opacity(0.30))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var displayValue: String {
        if let suffix { return "\(value)\(suffix)" }
        return "\(value)"
    }

    private func stepButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FCTheme.textMuted)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
