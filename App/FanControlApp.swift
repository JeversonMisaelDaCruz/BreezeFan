import SwiftUI
import AppKit

@main
struct FanControlApp: App {
    @State private var appState = AppState.shared

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

        // Background update check 30s after launch (don't block startup).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            await UpdateChecker.shared.checkForUpdates()
        }
    }

    var body: some Scene {
        WindowGroup {
            FCWindow {
                ZStack {
                    MainView()

                    if appState.unlockSheetPresented {
                        LicenseUnlockSheet(isPresented: Binding(
                            get: { appState.unlockSheetPresented },
                            set: { appState.unlockSheetPresented = $0 }
                        ))
                        .zIndex(11)
                    }

                    if appState.curveEditorPresented && appState.curveUnlocked {
                        CurveEditorView(isPresented: Binding(
                            get: { appState.curveEditorPresented },
                            set: { appState.curveEditorPresented = $0 }
                        ))
                        .zIndex(10)
                    }
                }
                .animation(FCAnimation.bouncy, value: appState.curveEditorPresented)
                .animation(FCAnimation.bouncy, value: appState.unlockSheetPresented)
            }
            .environment(appState)
            .frame(width: 360, height: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FanControl") {
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
                Button("Check for Updates…") {
                    Task { @MainActor in
                        if let update = await UpdateChecker.shared.checkForUpdates(force: true) {
                            // Banner will appear automatically via AppState observation.
                            _ = update
                        } else {
                            let alert = NSAlert()
                            alert.messageText = "FanControl está atualizado"
                            alert.informativeText = "Você está rodando a versão \(AppVersion.current.string)."
                            alert.alertStyle = .informational
                            alert.runModal()
                        }
                    }
                }
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
