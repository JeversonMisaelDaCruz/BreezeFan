import SwiftUI

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
                .animation(.spring(response: 0.26, dampingFraction: 0.85),
                           value: appState.curveEditorPresented)
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
