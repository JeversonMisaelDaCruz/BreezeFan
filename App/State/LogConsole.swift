import AppKit
import Foundation

/// Opens Console.app filtered to the helper's os_log subsystem. Wired via `Cmd-`.
enum LogConsole {
    static func open() {
        let consoleAppURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
        NSWorkspace.shared.open(consoleAppURL)
    }
}
