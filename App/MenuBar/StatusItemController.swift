import AppKit
import SwiftUI
import Combine

/// Bridges AppKit menu / status-item actions to SwiftUI's `openWindow`. AppKit
/// alone cannot re-create a SwiftUI scene window once it has been closed, so a
/// SwiftUI view captures the `openWindow` action into here for AppKit to call.
@MainActor
final class WindowAccess {
    static let shared = WindowAccess()
    /// Set by a SwiftUI view (MainView / popover) that owns the scene environment.
    var openMainWindow: (() -> Void)?
    private init() {}
}

/// Singleton controller for the menu bar (NSStatusItem) presence.
/// - Owns the NSStatusItem, its tooltip + reactive tint
/// - Owns the NSPopover used for left-click
/// - Owns the NSMenu used for right-click
/// - Reacts to AppState/snapshot changes via observation
@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let rightClickMenu: NSMenu
    private var lastTooltipUpdate: Date = .distantPast

    private var observerTask: Task<Void, Never>?
    private var appearanceObservation: NSKeyValueObservation?

    private override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.rightClickMenu = NSMenu()
        super.init()

        configureStatusItem()
        configurePopover()
        configureRightClickMenu()
        startObserving()
        observeAppearance()
    }

    deinit {
        appearanceObservation?.invalidate()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        // Initial image — palette color (no template).
        button.image = StatusIcon.makeImage(mode: .auto, smcConflict: false)
        button.toolTip = "BreezeFan"

        // Receive both left and right clicks; differentiate in handler.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(handleClick(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 270)
        let view = MenuBarPopoverView(onOpenWindow: { [weak self] in
            // The SwiftUI view opens the window via openWindow(id:); just dismiss here.
            self?.popover.performClose(nil)
        })
        .environment(AppState.shared)
        let host = NSHostingController(rootView: view)
        popover.contentViewController = host
    }

    private func configureRightClickMenu() {
        rightClickMenu.removeAllItems()

        // Version label (disabled, informational)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let versionItem = NSMenuItem(title: "BreezeFan \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        rightClickMenu.addItem(versionItem)

        rightClickMenu.addItem(.separator())

        let showWindow = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "0")
        showWindow.target = self
        rightClickMenu.addItem(showWindow)

        let editCurve = NSMenuItem(title: "Edit fan curve…", action: #selector(editCurve), keyEquivalent: "e")
        editCurve.target = self
        rightClickMenu.addItem(editCurve)

        let checkUpdates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdates.target = self
        rightClickMenu.addItem(checkUpdates)

        rightClickMenu.addItem(.separator())

        let menuBarOnly = NSMenuItem(title: "Menu bar only", action: #selector(toggleMenuBarOnly), keyEquivalent: "")
        menuBarOnly.target = self
        menuBarOnly.state = AppState.shared.menuBarOnly ? .on : .off
        rightClickMenu.addItem(menuBarOnly)

        let openSettings = NSMenuItem(title: "Open System Settings…", action: #selector(openLoginItems), keyEquivalent: "")
        openSettings.target = self
        rightClickMenu.addItem(openSettings)

        rightClickMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit BreezeFan", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        rightClickMenu.addItem(quit)
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // Show the right-click menu via popUpMenu
            statusItem.menu = rightClickMenu
            statusItem.button?.performClick(nil)
            // Reset menu so left-click next time triggers the popover instead
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
            return
        }

        togglePopover()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Refresh menu state
            configureRightClickMenu()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring popover to front so it can receive events even when other apps are focused.
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Menu actions

    @objc private func showWindow() {
        showMainWindow()
    }

    @objc private func editCurve() {
        showMainWindow()
        AppState.shared.curveEditorPresented = true
    }

    @objc private func toggleMenuBarOnly() {
        AppState.shared.menuBarOnly.toggle()
        applyActivationPolicy()
        configureRightClickMenu()
        AppState.shared.persistToStateStore()
    }

    @objc private func checkForUpdates() {
        // Sparkle handles its own UI (dialog with Install/Skip/Remind Later, or
        // "You're up to date" alert when no update is available).
        UpdaterController.shared?.checkForUpdates()
    }

    @objc private func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - State observation

    private func startObserving() {
        // Refresh tooltip + tint every 5s, matching the helper sampling cadence.
        observerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshIcon()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    /// Invalidate the cached image when the system appearance changes
    /// (light → dark or vice-versa). Template images update automatically
    /// via macOS, but we drop the cache key so the next `refreshIcon()`
    /// rebuilds without flash.
    private func observeAppearance() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.cachedImageState = nil
                self?.refreshIcon()
            }
        }
    }

    /// Refreshes the menu bar icon (palette color baked into the image) and tooltip.
    /// Tooltip throttled to every 2s so it doesn't change while user is reading it.
    /// The image is rebuilt only when state changes (cached comparison) — cheap to call
    /// on every 5s observer tick.
    private var cachedImageState: (mode: ControlMode.Kind, conflict: Bool)?

    func refreshIcon() {
        let snap = AppState.shared.snapshot
        let mode = AppState.shared.modeKind
        let conflict = snap.smcConflict

        // Rebuild image only when state actually changed (avoid pointless work every 1s).
        let newState = (mode: mode, conflict: conflict)
        if cachedImageState == nil ||
           cachedImageState!.mode != newState.mode ||
           cachedImageState!.conflict != newState.conflict {
            statusItem.button?.image = StatusIcon.makeImage(mode: mode, smcConflict: conflict)
            cachedImageState = newState
        }

        let now = Date()
        if now.timeIntervalSince(lastTooltipUpdate) >= 2.0 {
            statusItem.button?.toolTip = StatusIcon.tooltip(snapshot: snap)
            lastTooltipUpdate = now
        }
    }

    /// Force tooltip update (used when mode changes — instant feedback).
    func refreshTooltipNow() {
        statusItem.button?.toolTip = StatusIcon.tooltip(snapshot: AppState.shared.snapshot)
        lastTooltipUpdate = Date()
    }

    // MARK: - Helpers

    /// Shows (and re-creates if needed) the main window. Robust against the window
    /// having been closed: raises an existing main window, otherwise asks SwiftUI to
    /// re-open the `Window(id: "main")` scene via the WindowAccess bridge.
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            WindowAccess.shared.openMainWindow?()
        }
    }

    func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = AppState.shared.menuBarOnly ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }
}
