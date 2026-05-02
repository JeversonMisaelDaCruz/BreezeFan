import SwiftUI

/// 2x2 grid of MVP presets. Mirrors the Mode section in `main-mvp.jsx`.
struct PresetGrid: View {
    @Environment(AppState.self) private var appState
    @State private var inFlight: Preset?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Preset.allCases) { preset in
                PresetButton(
                    preset: preset,
                    isActive: appState.activePreset == preset
                ) {
                    apply(preset)
                }
                .disabled(appState.isReadOnly || inFlight != nil)
            }
        }
    }

    private func apply(_ preset: Preset) {
        inFlight = preset
        Task {
            do {
                try await HelperClient.shared.applyPreset(preset)
                await MainActor.run {
                    appState.activePreset = preset
                    appState.modeKind = preset == .balanced ? .auto : .forced
                    inFlight = nil
                }
            } catch {
                await MainActor.run {
                    inFlight = nil
                }
            }
        }
    }
}
