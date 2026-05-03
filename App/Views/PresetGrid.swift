import SwiftUI

/// 2x2 grid of MVP presets. Buttons disabled until helper provides real fan ceilings.
/// Keyboard shortcuts: ⌘1=Silent, ⌘2=Balanced, ⌘3=Performance, ⌘4=Max.
struct PresetGrid: View {
    @Environment(AppState.self) private var appState
    @State private var inFlight: Preset?
    @State private var lastError: String?

    // JSX `main-mvp.jsx:58` — `gridTemplateColumns: '1fr 1fr', gap: 6`.
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(Preset.allCases.enumerated()), id: \.element) { index, preset in
                    PresetButton(
                        preset: preset,
                        isActive: appState.activePreset == preset
                    ) {
                        apply(preset)
                    }
                    .disabled(isDisabled || inFlight != nil)
                    .keyboardShortcut(KeyEquivalent(shortcutKey(for: index)), modifiers: .command)
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
                    .transition(.opacity)
            }
            if let err = lastError {
                Text(err)
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.danger)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .animation(FCAnimation.fast, value: appState.fanCeilings == nil)
        .animation(FCAnimation.fast, value: lastError)
    }

    private var isDisabled: Bool {
        appState.isReadOnly || appState.fanCeilings == nil
    }

    private func shortcutKey(for index: Int) -> Character {
        switch index {
        case 0: return "1"  // Silent
        case 1: return "2"  // Balanced
        case 2: return "3"  // Performance
        case 3: return "4"  // Max
        default: return " "
        }
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
