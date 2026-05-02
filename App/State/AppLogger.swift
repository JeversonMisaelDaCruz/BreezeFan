import Foundation
import os.log

/// Logger for the App side. Uses public privacy so messages aren't redacted in Console.
enum AppLogger {
    static let main = Logger(subsystem: "com.fancontrol.app", category: "main")
    static let xpc = Logger(subsystem: "com.fancontrol.app", category: "xpc")
}
