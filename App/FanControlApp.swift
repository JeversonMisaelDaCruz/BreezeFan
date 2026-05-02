import SwiftUI

@main
struct FanControlApp: App {
    @State private var appState = AppState.shared

    init() {
        // Best-effort install of the helper. Triggers admin prompt the first time.
        let result = HelperClient.shared.installHelperIfNeeded()
        switch result {
        case .alreadyEnabled, .approved:
            break
        case .requiresApproval:
            // User must approve in System Settings → Login Items.
            break
        case .failed:
            break
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
