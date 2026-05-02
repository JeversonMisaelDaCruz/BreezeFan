import SwiftUI
import AppKit
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

    /// Fan ceilings reported by the helper after SMC boot. nil until first XPC fetch.
    /// Presets are disabled while nil.
    var fanCeilings: FanCeilings? = nil

    /// When true, app runs as `.accessory` (no Dock icon). Persisted in state.json.
    var menuBarOnly: Bool = false

    /// Helper status snapshot.
    var helperConnected: Bool = false
    var helperStatusMessage: String = "Connecting…"
    var smcConflict: Bool = false

    /// Last sensor snapshot rendered in UI.
    var snapshot: SensorSnapshot = .empty

    /// Curve editor sheet visibility.
    var curveEditorPresented: Bool = false

    /// Singleton.
    @MainActor static let shared = AppState()

    private let stateStore = StateStore()

    private init() {
        loadFromStateStore()
    }

    /// Loads persisted preferences from state.json.
    func loadFromStateStore() {
        let s = stateStore.load()
        self.accentHex = s.accentHex
        self.accentColor = Color(hex: s.accentHex)
        self.tempUnit = TempUnit(rawValue: s.tempUnit) ?? .celsius
        self.activeCurve = s.activeCurve
        self.activePreset = s.activePresetRaw.flatMap(Preset.init(rawValue:))
        self.menuBarOnly = s.menuBarOnly
    }

    /// Persists current state to state.json. Called on settings changes.
    func persistToStateStore() {
        let s = PersistedAppState(
            version: 1,
            accentHex: accentHex,
            tempUnit: tempUnit.rawValue,
            activeCurve: activeCurve,
            activePresetRaw: activePreset?.rawValue,
            menuBarOnly: menuBarOnly
        )
        try? stateStore.save(s)
    }

    func uninstallHelper() async {
        do {
            try await HelperClient.shared.uninstall()
            try await HelperClient.shared.uninstallHelper()
        } catch {
            try? await HelperClient.shared.uninstallHelper()
        }
    }

    /// Forces a fresh installation attempt. Used by the "Retry" banner button.
    func reinstallHelper() {
        let result = HelperClient.shared.installHelperIfNeeded()
        switch result {
        case .alreadyEnabled, .approved:
            helperStatusMessage = "Helper installed."
        case .requiresApproval:
            helperStatusMessage = "Approve in System Settings → Login Items"
            // Open System Settings to the right pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        case .failed(let msg):
            helperStatusMessage = "Install failed: \(msg)"
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
