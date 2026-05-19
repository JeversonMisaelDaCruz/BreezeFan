import AppKit

/// Pure helper for the menu bar status icon. Decides whether to use the
/// **template image idiom** (`isTemplate = true`, no palette) so macOS tints
/// the icon adaptively (white in dark mode, black in light mode — same as
/// Wi-Fi, battery, AirPlay) **or** to bake a warning color into the image
/// via palette config (red for forced, yellow for SMC conflict).
///
/// Background — user feedback "o icone na top bar deve ser branco":
///   - The previous approach used `paletteColors: [.controlAccentColor]`
///     for normal modes, making the icon accent-blue. User explicitly
///     rejected that and asked for the standard adaptive white-in-dark
///     idiom.
///   - The earlier "ícone preto" report was actually correct *template*
///     behaviour in light mode (template icons are black on light menu
///     bars). The fix is to embrace the template idiom, not work around it.
///
/// Decision matrix:
///
///   | mode    | smcConflict | result                                   |
///   |---------|-------------|------------------------------------------|
///   | auto    | false       | template (isTemplate=true), adaptive     |
///   | curve   | false       | template (isTemplate=true), adaptive     |
///   | forced  | false       | palette systemRed (warning, override)    |
///   | any     | true        | palette systemYellow (priority warning)  |
enum StatusIcon {

    /// Shared RPM formatter — allocated once at class load.
    /// NumberFormatter is heavy to construct; reusing it eliminates per-tooltip allocation
    /// (tooltip refreshes every ~2s when the menu bar item is visible).
    private static let rpmFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()

    /// Tooltip text for the status item — `BreezeFan · <temp> · <RPM>`.
    static func tooltip(snapshot: SensorSnapshot) -> String {
        let temp: String
        if let t = snapshot.cpuTemp {
            temp = "\(Int(t.rounded()))°C"
        } else {
            temp = "—"
        }
        let rpm: String
        if let r = snapshot.leftRPM {
            rpm = "\(rpmFormatter.string(from: NSNumber(value: r)) ?? "\(r)") RPM"
        } else {
            rpm = "— RPM"
        }
        return "BreezeFan · \(temp) · \(rpm)"
    }

    /// SF Symbol name with fallback if the primary glyph is unavailable.
    static func iconName(probing: (String) -> Bool = defaultProbe) -> String {
        if probing("fan.fill") { return "fan.fill" }
        return "gearshape.2.fill"
    }

    /// Builds an `NSImage` for the status item.
    ///
    /// For normal states (auto/curve, no conflict) the returned image has
    /// `isTemplate = true` and **no palette config** — macOS will tint it
    /// adaptively per appearance.
    ///
    /// For warning states (forced or smcConflict) the image is non-template
    /// with a palette color baked in so the warning color survives any
    /// appearance change.
    @MainActor
    static func makeImage(mode: ControlMode.Kind, smcConflict: Bool) -> NSImage? {
        let name = iconName()
        let baseConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: "BreezeFan") else {
            return nil
        }

        // Warning paths — palette wins, image is non-template.
        if smcConflict {
            return paletteImage(base: base,
                                config: baseConfig,
                                color: .systemYellow)
        }
        if mode == .forced {
            return paletteImage(base: base,
                                config: baseConfig,
                                color: .systemRed)
        }

        // Normal path — template idiom. macOS tints adaptively.
        let image = base.withSymbolConfiguration(baseConfig)
        image?.isTemplate = true
        return image
    }

    // MARK: - Helpers

    @MainActor
    private static func paletteImage(base: NSImage,
                                     config: NSImage.SymbolConfiguration,
                                     color: NSColor) -> NSImage? {
        let palette = NSImage.SymbolConfiguration(paletteColors: [color])
        let merged = config.applying(palette)
        let image = base.withSymbolConfiguration(merged)
        image?.isTemplate = false
        return image
    }

    private static func defaultProbe(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}
