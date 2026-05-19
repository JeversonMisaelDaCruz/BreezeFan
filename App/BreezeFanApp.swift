import SwiftUI
import AppKit

@main
struct BreezeFanApp: App {
    @State private var appState = AppState.shared

    /// Sparkle auto-updater. `startingUpdater: true` triggers automatic background
    /// check on launch (according to SUScheduledCheckInterval in Info.plist).
    @StateObject private var updaterController = UpdaterController()

    init() {
        // Best-effort install attempt on launch. The result is intentionally
        // discarded — the first XPC poll surfaces reachability through
        // SensorViewModel.helperReachable + lastError, which the offline banner
        // already observes.
        _ = HelperClient.shared.installHelperIfNeeded()

        // Bring up the menu bar status item BEFORE the window so the icon is
        // visible immediately at launch.
        _ = StatusItemController.shared

        // Apply activation policy from persisted setting.
        StatusItemController.shared.applyActivationPolicy()
    }

    var body: some Scene {
        WindowGroup {
            FCWindow {
                ZStack {
                    MainView()

                    if appState.curveEditorPresented {
                        CurveEditorView(isPresented: Binding(
                            get: { appState.curveEditorPresented },
                            set: { appState.curveEditorPresented = $0 }
                        ))
                        .zIndex(10)
                    }
                }
                .animation(FCAnimation.bouncy, value: appState.curveEditorPresented)
            }
            .environment(appState)
            .frame(width: 360, height: 640)
        }
        // Default `.titleBar` window style — let macOS draw the titlebar with its
        // native traffic lights in the correct OS position. The user explicitly
        // rejected the custom Liquid Glass titlebar attempts ("ainda ficaram
        // bugadas fora do lgar… só deixe minimalista preto"). Native is simpler
        // and visually predictable on every macOS version.
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BreezeFan") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Show Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeKey {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .keyboardShortcut("0", modifiers: .command)

                CheckForUpdatesView(updater: updaterController.updater)

                Divider()
                Button("Open System Settings (Login Items)") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Reinstall helper") {
                    appState.reinstallHelper()
                }
                Divider()
                Button("Open logs in Console…") {
                    LogConsole.open()
                }
                Divider()
                Button("Uninstall helper…") {
                    Task { await appState.uninstallHelper() }
                }
            }
        }
    }
}
