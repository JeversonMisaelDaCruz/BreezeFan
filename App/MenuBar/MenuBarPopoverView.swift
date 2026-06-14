import SwiftUI
import AppKit

/// Compact popover content shown when the menu bar icon is left-clicked.
/// Reuses PresetGrid + a small temp display. 320×180 pt total.
struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var sensorVM = SensorViewModel()

    /// Closure called when user taps "Open BreezeFan →" — host wires it to popover dismiss + window-front.
    var onOpenWindow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: FCSpacing.sm) {
            tempBlock
            Divider().opacity(0.3)
            PresetGrid()
                .disabled(!sensorVM.helperReachable || appState.fanCeilings == nil)
                .opacity((sensorVM.helperReachable && appState.fanCeilings != nil) ? 1.0 : 0.4)
            CurveModeRow()
                .disabled(!sensorVM.helperReachable || appState.fanCeilings == nil)
                .opacity((sensorVM.helperReachable && appState.fanCeilings != nil) ? 1.0 : 0.4)
            HStack {
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                    onOpenWindow()
                } label: {
                    Text("Open BreezeFan →")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(appState.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FCSpacing.md)
        .frame(width: 320)
        .onAppear {
            sensorVM.start()
            Task { await sensorVM.pollOnce() }
            // Capture the scene's openWindow so AppKit menus can reopen the window.
            WindowAccess.shared.openMainWindow = { openWindow(id: "main") }
        }
        .onDisappear {
            sensorVM.stop()
        }
    }

    private var tempBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(appState.formatTemp(sensorVM.snapshot.cpuTemp))
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(FCTheme.textPrimary)
                    .fcTabularNums()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.1), value: sensorVM.snapshot.cpuTemp)
                Text(appState.tempUnitSuffix())
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(FCTheme.textMuted)
            }
            Text(sensorVM.subtext(unit: appState.tempUnit))
                .font(.system(size: 9))
                .foregroundStyle(FCTheme.textMuted)
        }
    }
}
