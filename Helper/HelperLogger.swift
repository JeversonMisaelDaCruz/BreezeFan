import Foundation
import os.log

/// Wrappers around `os.Logger` for the helper. Categories show in Console.app.
public enum HelperLogger {
    public static let control  = Logger(subsystem: "com.fancontrol.helper", category: "control")
    public static let safety   = Logger(subsystem: "com.fancontrol.helper", category: "safety")
    public static let xpc      = Logger(subsystem: "com.fancontrol.helper", category: "xpc")
    public static let smc      = Logger(subsystem: "com.fancontrol.helper", category: "smc")
    public static let sensors  = Logger(subsystem: "com.fancontrol.helper", category: "sensors")
}

extension Logger {
    func warn(_ msg: @autoclosure () -> String) {
        self.warning("\(msg(), privacy: .public)")
    }
    func log(_ msg: @autoclosure () -> String) {
        self.info("\(msg(), privacy: .public)")
    }
}
