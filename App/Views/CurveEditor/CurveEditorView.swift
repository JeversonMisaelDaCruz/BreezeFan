import SwiftUI

/// Modal sheet for editing the active fan curve. Mirrors `CurveMVP` in `curve-mvp.jsx`.
struct CurveEditorView: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @State private var draftSteps: [CurveStep] = Curve.default.steps
    @State private var validationError: CurveError?
    @State private var saving: Bool = false

    private var draftCurve: Curve {
        Curve(steps: draftSteps.sorted { $0.temp < $1.temp })
    }

    var body: some View {
        ZStack {
            // Backdrop dim — wallpaper still visible behind it through opacity.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { /* swallow */ }

            FCGlassSurface(radius: FCRadius.sheet, intensity: 1.0, sheen: true) {
                VStack(spacing: 0) {
                    header
                    FCDivider()
                    graphSection
                    FCDivider()
                    stepsSection
                    Spacer()
                    if let err = validationError {
                        Text(errorMessage(err))
                            .font(.system(size: 11))
                            .foregroundStyle(FCTheme.danger)
                            .padding(.bottom, 8)
                    }
                }
            }
            .padding(FCSpacing.sm)
        }
        .onAppear {
            draftSteps = appState.activeCurve.steps.isEmpty
                ? Curve.default.steps
                : appState.activeCurve.steps
            validate()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button("Cancel") { isPresented = false }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(FCTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)

            Spacer()
            Text("Fan Curve")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FCTheme.textPrimary)
            Spacer()

            Button(action: save) {
                Text("Save")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appState.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(appState.accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(appState.accentColor.opacity(0.35), lineWidth: 0.5)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(validationError != nil || saving)
            .opacity(validationError == nil ? 1 : 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 44)
    }

    private var graphSection: some View {
        FCSection(title: "Preview") {
            CurveGraph(curve: draftCurve)
        }
    }

    private var stepsSection: some View {
        FCSection(title: "Steps") {
            VStack(spacing: 4) {
                ForEach(Array(draftSteps.indices), id: \.self) { idx in
                    StepRow(
                        step: $draftSteps[idx],
                        canRemove: draftSteps.count > 2,
                        onRemove: { remove(idx) },
                        onChange: validate
                    )
                }
            }
        } action: {
            Button {
                addStep()
            } label: {
                Text("+ Add")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(draftSteps.count < 6 ? appState.accentColor : FCTheme.textGhost)
            }
            .buttonStyle(.plain)
            .disabled(draftSteps.count >= 6)
            .opacity(draftSteps.count < 6 ? 1 : 0.25)
        }
    }

    // MARK: - Actions

    private func addStep() {
        guard draftSteps.count < 6 else { return }
        let last = draftSteps.last ?? CurveStep(temp: 30, duty: 10)
        let next = CurveStep(
            temp: min(last.temp + 5, 105),
            duty: min(last.duty + 5, 100)
        )
        draftSteps.append(next)
        validate()
    }

    private func remove(_ idx: Int) {
        guard draftSteps.count > 2, draftSteps.indices.contains(idx) else { return }
        draftSteps.remove(at: idx)
        validate()
    }

    private func validate() {
        let curve = draftCurve
        if case .failure(let err) = CurveValidator.validate(curve) {
            validationError = err
        } else {
            validationError = nil
        }
    }

    private func save() {
        let curve = draftCurve
        guard case .success = CurveValidator.validate(curve) else { return }
        saving = true
        Task {
            do {
                try await HelperClient.shared.setCurve(curve)
                try await HelperClient.shared.setMode(.curve)
                await MainActor.run {
                    appState.activeCurve = curve
                    appState.modeKind = .curve
                    isPresented = false
                    saving = false
                }
            } catch {
                await MainActor.run {
                    saving = false
                }
            }
        }
    }

    private func errorMessage(_ err: CurveError) -> String {
        switch err {
        case .tooFewSteps:        return "Curve needs at least 2 steps."
        case .tooManySteps:       return "Curve cannot have more than 6 steps."
        case .unordered:          return "Steps must be in ascending temperature order."
        case .duplicateTemp:      return "Cannot have two steps at the same temperature."
        case .invalidTempRange:   return "Temperature must be between 20°C and 105°C."
        case .invalidDutyRange:   return "Duty must be between 0% and 100%."
        }
    }
}

/// One row in the steps editor.
struct StepRow: View {
    @Binding var step: CurveStep
    let canRemove: Bool
    let onRemove: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NumStepper(
                value: Binding(
                    get: { step.temp },
                    set: { step.temp = $0; onChange() }
                ),
                range: 20...105,
                step: 1,
                suffix: "°"
            )
            NumStepper(
                value: Binding(
                    get: { step.duty },
                    set: { step.duty = $0; onChange() }
                ),
                range: 0...100,
                step: 5,
                suffix: "%"
            )
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(canRemove ? FCTheme.textMuted : FCTheme.textGhost)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
        }
    }
}
