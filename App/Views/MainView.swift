import SwiftUI

/// Main window content. Mirrors `FanControl/app/main-mvp.jsx`.
/// Fase 1: temp readout + fan list driven by SensorViewModel.
/// Fase 2: PresetGrid wires up the bottom Mode section.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var sensorVM = SensorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            FCDivider()

            tempReadout

            FCDivider()

            fansSection

            FCDivider()

            modeSection

            Spacer()

            footer
        }
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
            HStack {
                Spacer()
                if appState.isReadOnly {
                    Text("READ-ONLY")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FCTheme.warn.opacity(0.2))
                        .foregroundStyle(FCTheme.warn)
                        .cornerRadius(4)
                        .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
    }

    private var tempReadout: some View {
        FCSection(title: "CPU temperature", topPadding: 16, bottomPadding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appState.formatTemp(sensorVM.snapshot.cpuTemp))
                        .font(FCFont.display)
                        .foregroundStyle(FCTheme.textPrimary)
                        .fcTabularNums()
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
        }
    }

    private var footer: some View {
        Button {
            appState.curveEditorPresented = true
        } label: {
            Text("Edit fan curve →")
                .font(FCFont.body)
                .foregroundStyle(FCTheme.textGhost)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .top) {
            FCDivider().padding(.horizontal, -18)
        }
    }
}
