import Foundation
import Sparkle

/// SwiftUI-friendly wrapper around `SPUStandardUpdaterController`.
///
/// Sparkle 2 ships `SPUStandardUpdaterController` as a NSObject conforming to
/// `ObservableObject` (works fine with `@StateObject`). We just hold the
/// instance and expose `updater` so views can bind a "Check for Updates…"
/// button to it.
///
/// Configuration comes from Info.plist:
///   - SUFeedURL: appcast.xml URL
///   - SUPublicEDKey: EdDSA public key
///   - SUEnableAutomaticChecks: true
///   - SUScheduledCheckInterval: 86400 (24h)
///
/// `startingUpdater: true` means Sparkle's automatic background check runs
/// on app launch (according to SUScheduledCheckInterval).
final class UpdaterController: ObservableObject {
    /// Shared instance assigned by `BreezeFanApp` on init. Allows non-SwiftUI code
    /// (e.g. NSStatusItem menu) to trigger checks without weaving the controller
    /// through every view layer.
    static var shared: UpdaterController?

    let controller: SPUStandardUpdaterController

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        UpdaterController.shared = self
    }

    /// Programmatically force a check (instant). Used by "Check for Updates…" menu items.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// True when an update check is currently in flight (Sparkle exposes this).
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    /// Underlying SPUUpdater for advanced usage (e.g. checkForUpdatesInBackground()).
    var updater: SPUUpdater {
        controller.updater
    }
}
