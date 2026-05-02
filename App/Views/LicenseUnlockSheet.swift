import SwiftUI

/// Modal sheet asking the user for the activation key required to unlock the curve editor.
/// Mirrors the `CurveEditorView` chrome (header + Cancel/title/action) for visual consistency.
struct LicenseUnlockSheet: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @State private var key: String = ""
    @State private var errorMessage: String?
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { /* swallow */ }

            VStack(spacing: 0) {
                header
                FCDivider()

                FCSection(title: "Activation key", topPadding: FCSpacing.lg) {
                    VStack(alignment: .leading, spacing: FCSpacing.sm) {
                        Text("Insira a chave para liberar o editor de curva.")
                            .font(.system(size: 11))
                            .foregroundStyle(FCTheme.textMuted)

                        SecureField("Chave de ativação", text: $key)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(FCTheme.textPrimary)
                            .padding(.horizontal, FCSpacing.md)
                            .padding(.vertical, FCSpacing.sm + 2)
                            .background(Color.black.opacity(0.30))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(borderColor, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .focused($keyFieldFocused)
                            .onSubmit { attemptUnlock() }

                        if let err = errorMessage {
                            HStack(spacing: FCSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                Text(err)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(FCTheme.danger)
                            .transition(.opacity)
                        }
                    }
                }

                Spacer()

                FCSection(title: nil, topPadding: FCSpacing.sm, bottomPadding: FCSpacing.lg) {
                    HStack {
                        Spacer()
                        Text("Esta chave libera o controle por curva personalizada.")
                            .font(.system(size: 9))
                            .foregroundStyle(FCTheme.textGhost)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                }
            }
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Auto-focus the field after the sheet animates in.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                keyFieldFocused = true
            }
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
                .padding(.horizontal, FCSpacing.sm + 2)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .keyboardShortcut(.cancelAction)

            Spacer()

            HStack(spacing: FCSpacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Unlock Fan Curve")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(FCTheme.textPrimary)

            Spacer()

            Button(action: attemptUnlock) {
                Text("Unlock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appState.accentColor)
                    .padding(.horizontal, FCSpacing.sm + 2)
                    .padding(.vertical, 5)
                    .background(appState.accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(appState.accentColor.opacity(0.35), lineWidth: 0.5)
                    )
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, FCSpacing.md + 2)
        .padding(.vertical, FCSpacing.sm + 2)
        .frame(height: 44)
    }

    private var borderColor: Color {
        if errorMessage != nil { return FCTheme.danger.opacity(0.4) }
        if keyFieldFocused { return appState.accentColor.opacity(0.45) }
        return Color.white.opacity(0.06)
    }

    // MARK: - Actions

    private func attemptUnlock() {
        let ok = appState.validateAndUnlockCurve(key)
        if ok {
            withAnimation(FCAnimation.normal) {
                isPresented = false
            }
        } else {
            withAnimation(FCAnimation.fast) {
                errorMessage = "Chave incorreta. Verifique e tente novamente."
            }
            // Clear field for retry but keep error visible.
            key = ""
        }
    }
}
