import SwiftUI
import Observation

/// Top-level UI state. `@Observable` (Swift 5.9+) provides automatic dependency tracking.
@Observable
@MainActor
final class AppState {
    enum TempUnit: String, Codable, CaseIterable, Identifiable {
        case celsius = "C"
        case fahrenheit = "F"
        var id: String { rawValue }
    }

    /// Accent color used for the window glow + accents.
    var accentColor: Color = FCTheme.accentBlue

    /// Persisted accent as hex string.
    var accentHex: String = "#3b82f6"

    /// Display unit for temperature.
    var tempUnit: TempUnit = .celsius

    /// Active preset (nullable when curve mode is on without a preset choice).
    var activePreset: Preset? = nil

    /// Current control mode reported by helper.
    var modeKind: ControlMode.Kind = .auto

    /// Active curve (default when first opening editor).
    var activeCurve: Curve = .default

    /// Hardware lock — true when running on non-MacBookPro18,3.
    var isReadOnly: Bool = false
    var modelIdentifier: String = ""

    /// Helper status snapshot.
    var helperConnected: Bool = false
    var smcConflict: Bool = false

    /// Last sensor snapshot rendered in UI.
    var snapshot: SensorSnapshot = .empty

    /// Curve editor sheet visibility.
    var curveEditorPresented: Bool = false

    /// Singleton.
    @MainActor static let shared = AppState()

    private init() {}

    func uninstallHelper() async {
        do {
            try await HelperClient.shared.uninstall()
            try await HelperClient.shared.uninstallHelper()
        } catch {
            // Best-effort — uninstall may proceed even if XPC fails.
            try? await HelperClient.shared.uninstallHelper()
        }
    }

    /// Convert raw °C to user-visible string respecting `tempUnit`.
    func formatTemp(_ celsius: Double?) -> String {
        guard let celsius else { return "—" }
        switch tempUnit {
        case .celsius:    return "\(Int(celsius.rounded()))"
        case .fahrenheit: return "\(Int((celsius * 9.0/5.0 + 32.0).rounded()))"
        }
    }

    func tempUnitSuffix() -> String {
        tempUnit == .celsius ? "°C" : "°F"
    }

    #if DEBUG
    static let preview: AppState = {
        let s = AppState.shared
        s.accentColor = FCTheme.accentBlue
        return s
    }()
    #endif
}
