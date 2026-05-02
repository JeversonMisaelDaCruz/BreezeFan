import SwiftUI
import Sparkle

/// A SwiftUI Button that triggers Sparkle's "Check for Updates…" flow.
/// Disabled while a check is in flight (Sparkle reports `canCheckForUpdates`).
///
/// Used inside `CommandGroup` of the macOS top menu, but also reusable
/// elsewhere if needed.
struct CheckForUpdatesView: View {
    @ObservedObject private var checker: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        self.checker = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: checker.checkForUpdates)
            .disabled(!checker.canCheckForUpdates)
    }
}

/// Tracks `SPUUpdater.canCheckForUpdates` via KVO so the button updates live.
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
