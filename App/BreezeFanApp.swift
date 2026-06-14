import SwiftUI
import AppKit

/// Keeps the app alive in the menu bar when the main window is closed.
/// This is a status-bar–resident app (NSStatusItem), so closing the single
/// `Window` must NOT terminate the process — otherwise the menu-bar icon
/// disappears and the app becomes unusable until relaunch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct BreezeFanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState.shared

    /// Sparkle auto-updater. `startingUpdater: true` triggers automatic background
    /// check on launch (according to SUScheduledCheckInterval in Info.plist).
    @StateObject private var updaterController = UpdaterController()

    init() {
        // Best-effort install attempt on launch.
        let result = HelperClient.shared.installHelperIfNeeded()
        let state = AppState.shared
        switch result {
        case .alreadyEnabled:
            state.helperConnected = true
            state.helperStatusMessage = "Helper running."
        case .approved:
            state.helperStatusMessage = "Installed. Waiting for daemon to spawn…"
        case .requiresApproval:
            state.helperStatusMessage = "Approve in System Settings → Login Items"
        case .failed(let msg):
            state.helperStatusMessage = "Install failed: \(msg)"
        }

        // Bring up the menu bar status item BEFORE the window so the icon is
        // visible immediately at launch.
        _ = StatusItemController.shared

        // Apply activation policy from persisted setting.
        StatusItemController.shared.applyActivationPolicy()
    }

    var body: some Scene {
        // Single `Window` (not WindowGroup) so it can be reliably re-opened via
        // `openWindow(id: "main")` after the user closes it — see WindowAccess.
        Window("BreezeFan", id: "main") {
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
            .frame(width: 360, height: 690)
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
                    StatusItemController.shared.showMainWindow()
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
