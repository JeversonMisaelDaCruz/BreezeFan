import SwiftUI

/// Type scale for the BreezeFan UI. Mirrors the JSX `fontSize`/`letterSpacing` values.
public enum FCFont {
    /// Default body text: SF Pro 11pt.
    public static let body = Font.system(size: 11, weight: .regular, design: .default)

    /// Numeric values that need vertical alignment in tabular columns.
    public static let mono = Font.system(size: 11, weight: .regular, design: .monospaced)

    /// Section title — uppercase, 10pt, letter-spaced.
    public static let sectionTitle = Font.system(size: 10, weight: .semibold, design: .default)

    /// Window header title.
    public static let windowTitle = Font.system(size: 12, weight: .semibold, design: .default)

    /// Big number display (CPU temperature 64pt thin).
    public static let display = Font.system(size: 64, weight: .thin, design: .default)

    /// Step values inside NumStepper.
    public static let stepperValue = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Hover badges on the curve graph.
    public static let badge = Font.system(size: 8, weight: .medium, design: .monospaced)

    /// Subtext under the temp readout.
    public static let subtext = Font.system(size: 11, weight: .regular, design: .default)
}

extension View {
    /// Apply tabular-nums to a text view so 4280 / 5810 align vertically.
    func fcTabularNums() -> some View {
        self.monospacedDigit()
    }
}
