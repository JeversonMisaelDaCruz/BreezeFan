import AppKit
import SwiftUI
import Combine

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

    private override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.rightClickMenu = NSMenu()
        super.init()

        configureStatusItem()
        configurePopover()
        configureRightClickMenu()
        startObserving()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let iconName = StatusIcon.iconName()
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "FanControl")
        button.image?.isTemplate = true
        button.toolTip = "FanControl"

        // Receive both left and right clicks; differentiate in handler.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(handleClick(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 220)
        let view = MenuBarPopoverView(onOpenWindow: { [weak self] in
            self?.openMainWindow()
            self?.popover.performClose(nil)
        })
        .environment(AppState.shared)
        let host = NSHostingController(rootView: view)
        popover.contentViewController = host
    }

    private func configureRightClickMenu() {
        rightClickMenu.removeAllItems()

        let showWindow = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "0")
        showWindow.target = self
        rightClickMenu.addItem(showWindow)

        let editCurve = NSMenuItem(title: "Edit fan curve…", action: #selector(editCurve), keyEquivalent: "e")
        editCurve.target = self
        rightClickMenu.addItem(editCurve)

        rightClickMenu.addItem(.separator())

        let menuBarOnly = NSMenuItem(title: "Menu bar only", action: #selector(toggleMenuBarOnly), keyEquivalent: "")
        menuBarOnly.target = self
        menuBarOnly.state = AppState.shared.menuBarOnly ? .on : .off
        rightClickMenu.addItem(menuBarOnly)

        let openSettings = NSMenuItem(title: "Open System Settings…", action: #selector(openLoginItems), keyEquivalent: "")
        openSettings.target = self
        rightClickMenu.addItem(openSettings)

        rightClickMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit FanControl", action: #selector(quitApp), keyEquivalent: "q")
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
        openMainWindow()
    }

    @objc private func editCurve() {
        AppState.shared.curveEditorPresented = true
        openMainWindow()
    }

    @objc private func toggleMenuBarOnly() {
        AppState.shared.menuBarOnly.toggle()
        applyActivationPolicy()
        configureRightClickMenu()
        AppState.shared.persistToStateStore()
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
        // Update tooltip + tint every 1s based on snapshot/mode/conflict.
        observerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshIcon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Refreshes tooltip + tint. Tooltip throttled to every 2s (so it doesn't change while user is reading it).
    func refreshIcon() {
        let snap = AppState.shared.snapshot
        let mode = AppState.shared.modeKind
        let conflict = snap.smcConflict
        statusItem.button?.contentTintColor = StatusIcon.tint(mode: mode, smcConflict: conflict)

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

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Also explicitly raise the first window of the WindowGroup.
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = AppState.shared.menuBarOnly ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }
}
