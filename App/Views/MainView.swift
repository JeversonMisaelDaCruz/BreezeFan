import SwiftUI

/// Main window content. Mirrors `FanControl/app/main-mvp.jsx`.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var sensorVM = SensorViewModel()
    @State private var footerHovered = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if !sensorVM.helperReachable {
                helperOfflineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            FCDivider()

            tempReadout

            FCDivider()

            fansSection

            FCDivider()

            modeSection

            Spacer()

            footer
        }
        .animation(FCAnimation.normal, value: sensorVM.helperReachable)
        .onAppear { sensorVM.start() }
        .onDisappear { sensorVM.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:     sensorVM.start(); Task { await sensorVM.pollOnce() }
            case .background, .inactive: sensorVM.stop()
            @unknown default: break
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        ZStack {
            Text("FanControl")
                .font(FCFont.windowTitle)
                .foregroundStyle(FCTheme.textPrimary)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
    }

    private var helperOfflineBanner: some View {
        HStack(spacing: FCSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(FCTheme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Helper offline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FCTheme.textPrimary)
                Text(sensorVM.lastError ?? "Approve helper in System Settings.")
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.textMuted)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                appState.reinstallHelper()
                Task { await sensorVM.pollOnce() }
            } label: {
                Text("Retry")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FCTheme.warn)
                    .padding(.horizontal, FCSpacing.sm)
                    .padding(.vertical, 3)
                    .background(FCTheme.warn.opacity(0.15))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FCSpacing.md + 2)
        .padding(.vertical, FCSpacing.sm)
        .background(FCTheme.warn.opacity(0.08))
    }

    private var tempReadout: some View {
        FCSection(title: "CPU temperature", topPadding: FCSpacing.lg, bottomPadding: FCSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: FCSpacing.xs) {
                    Text(appState.formatTemp(sensorVM.snapshot.cpuTemp))
                        .font(FCFont.display)
                        .foregroundStyle(FCTheme.textPrimary)
                        .fcTabularNums()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.1), value: sensorVM.snapshot.cpuTemp)
                    Text(appState.tempUnitSuffix())
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(FCTheme.textMuted)
                }
                Text(sensorVM.subtext(unit: appState.tempUnit))
                    .font(FCFont.subtext)
                    .foregroundStyle(FCTheme.textMuted)
            }
        }
    }

    private var fansSection: some View {
        FCSection(title: "Fans") {
            VStack(spacing: 6) {
                FanRow(label: "Left Fan",
                       rpm: sensorVM.snapshot.leftRPM,
                       duty: sensorVM.snapshot.leftDuty)
                FanRow(label: "Right Fan",
                       rpm: sensorVM.snapshot.rightRPM,
                       duty: sensorVM.snapshot.rightDuty)
            }
        }
    }

    private var modeSection: some View {
        FCSection(title: "Mode") {
            PresetGrid()
                .disabled(!sensorVM.helperReachable)
                .opacity(sensorVM.helperReachable ? 1.0 : 0.4)
        }
    }

    private var footer: some View {
        // The button label changes based on lock state but always responds to ⌘E.
        Button(action: handleFooterTap) {
            HStack(spacing: FCSpacing.xs) {
                if !appState.curveUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(footerLabel)
                    .font(FCFont.body)
            }
            .foregroundStyle(footerForegroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FCSpacing.md)
        }
        .buttonStyle(.plain)
        .background(footerHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
        .overlay(alignment: .top) {
            FCDivider().padding(.horizontal, -FCSpacing.lg)
        }
        .keyboardShortcut("e", modifiers: .command)
        .disabled(!sensorVM.helperReachable)
        .opacity(sensorVM.helperReachable ? 1.0 : 0.4)
        .onHover { hovering in
            footerHovered = hovering
            if sensorVM.helperReachable {
                if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
        }
        .animation(FCAnimation.fast, value: footerHovered)
        .animation(FCAnimation.normal, value: appState.curveUnlocked)
    }

    private var footerLabel: String {
        appState.curveUnlocked ? "Edit fan curve →" : "Unlock fan curve"
    }

    private var footerForegroundColor: Color {
        if !appState.curveUnlocked {
            return footerHovered ? appState.accentColor : FCTheme.textMuted
        }
        return footerHovered ? FCTheme.textMuted : FCTheme.textGhost
    }

    private func handleFooterTap() {
        if appState.curveUnlocked {
            appState.curveEditorPresented = true
        } else {
            appState.unlockSheetPresented = true
        }
    }
}
