import SwiftUI

/// Full-width "Curva de Fan" control shown beneath the preset grid in the menu-bar popover.
///
/// A fan curve is a distinct `ControlMode` (not a fixed-RPM tier), so it lives OUTSIDE
/// `PresetGrid` rather than as a 5th preset. Activating it mirrors `CurveEditorView.save()`:
/// it pushes the app's active curve to the helper (`setCurve`) and switches to curve mode
/// (`setMode(.curve)`). Pushing the curve first guarantees the helper always has a valid
/// curve, so curve mode can never be a silent no-op (`ControlLoop.applyCurve` guards on nil).
///
/// Active state is driven by `AppState.modeKind == .curve`; activating it clears
/// `activePreset` so the five controls {Silent, Balanced, Performance, Max, Curva de Fan}
/// are mutually exclusive in the UI.
struct CurveModeRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.isEnabled) private var isEnabled
    @State private var inFlight = false
    @State private var lastError: String?
    @State private var hovered = false

    private var accent: Color { appState.accentColor }
    private var isActive: Bool { appState.modeKind == .curve }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: apply) {
                ZStack {
                    background
                    HStack(spacing: 8) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                        Text("Curva de Fan")
                            .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? .white : .white.opacity(0.8))
                        Spacer()
                        if inFlight {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(inFlight)
            .keyboardShortcut(KeyEquivalent("5"), modifiers: .command)
            .accessibilityLabel("Curva de Fan mode")
            .accessibilityValue(isActive ? "selected" : "")
            .onHover { newValue in
                hovered = newValue
                if isEnabled {
                    if newValue { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                }
            }
            .animation(FCAnimation.fast, value: hovered)
            .animation(FCAnimation.normal, value: isActive)

            if let err = lastError {
                Text(err)
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.danger)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .animation(FCAnimation.fast, value: lastError)
    }

    // MARK: - Background (active vs inactive) — mirrors PresetButton.

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if isActive {
            shape
                .fill(accent.opacity(0.20))
                .overlay(shape.strokeBorder(accent.opacity(0.55), lineWidth: 0.5))
        } else {
            shape
                .fill(Color.white.opacity(hovered && isEnabled ? 0.06 : 0.04))
                .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    private func apply() {
        inFlight = true
        lastError = nil
        let curve = appState.activeCurve
        Task {
            do {
                // Push the curve first so the helper always has one, then enter curve mode.
                try await HelperClient.shared.setCurve(curve)
                try await HelperClient.shared.setMode(.curve)
                await MainActor.run {
                    appState.modeKind = .curve
                    appState.activePreset = nil
                    inFlight = false
                    lastError = nil
                }
            } catch {
                await MainActor.run {
                    inFlight = false
                    lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                }
            }
        }
    }
}
