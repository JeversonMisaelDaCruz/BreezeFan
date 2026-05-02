import SwiftUI

/// 2x2 grid of MVP presets. Buttons disabled until helper provides real fan ceilings.
struct PresetGrid: View {
    @Environment(AppState.self) private var appState
    @State private var inFlight: Preset?
    @State private var lastError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Preset.allCases) { preset in
                    PresetButton(
                        preset: preset,
                        isActive: appState.activePreset == preset
                    ) {
                        apply(preset)
                    }
                    .disabled(isDisabled || inFlight != nil)
                    .overlay(
                        Group {
                            if inFlight == preset {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            }
                        }
                    )
                }
            }
            if appState.fanCeilings == nil {
                Text("Aguardando dados do helper…")
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.textGhost)
            }
            if let err = lastError {
                Text(err)
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.danger)
                    .lineLimit(2)
            }
        }
    }

    private var isDisabled: Bool {
        appState.isReadOnly || appState.fanCeilings == nil
    }

    private func apply(_ preset: Preset) {
        guard let ceilings = appState.fanCeilings else {
            lastError = "Ceilings do hardware indisponíveis"
            return
        }
        inFlight = preset
        lastError = nil
        let mode = preset.targetMode(f0Mx: ceilings.f0Mx, f1Mx: ceilings.f1Mx)
        Task {
            do {
                try await HelperClient.shared.setMode(mode)
                await MainActor.run {
                    appState.activePreset = preset
                    appState.modeKind = preset == .balanced ? .auto : .forced
                    inFlight = nil
                    lastError = nil
                }
            } catch {
                await MainActor.run {
                    inFlight = nil
                    lastError = (error as? LocalizedError)?.errorDescription
                                ?? "\(error)"
                }
            }
        }
    }
}
