import AppKit

/// Pure-logic helper to compute the tint color for the menu bar status icon
/// from the current control mode + smcConflict flag. Tested in isolation.
enum StatusIcon {
    /// Tint color for the status icon. Always returns a non-nil color so the icon
    /// is never just black/white template — always visibly colored.
    /// - smcConflict has highest priority (yellow) — overrides mode color.
    /// - mode=auto → secondaryLabelColor (adaptive gray, visible in light + dark)
    /// - mode=curve → controlAccentColor (user accent — usually blue)
    /// - mode=forced → systemRed
    static func tint(mode: ControlMode.Kind, smcConflict: Bool) -> NSColor? {
        if smcConflict { return .systemYellow }
        switch mode {
        case .auto:   return .secondaryLabelColor
        case .curve:  return .controlAccentColor
        case .forced: return .systemRed
        }
    }

    /// Tooltip text for the status item. Always shows temp + leftRPM.
    static func tooltip(snapshot: SensorSnapshot) -> String {
        let temp: String
        if let t = snapshot.cpuTemp {
            temp = "\(Int(t.rounded()))°C"
        } else {
            temp = "—"
        }
        let rpm: String
        if let r = snapshot.leftRPM {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            rpm = "\(f.string(from: NSNumber(value: r)) ?? "\(r)") RPM"
        } else {
            rpm = "— RPM"
        }
        return "\(temp) · \(rpm)"
    }

    /// Returns the SF Symbol name for the icon, with fallback if primary unavailable.
    static func iconName(probing: (String) -> Bool = defaultProbe) -> String {
        if probing("fan.fill") { return "fan.fill" }
        return "gearshape.2.fill"
    }

    private static func defaultProbe(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}
