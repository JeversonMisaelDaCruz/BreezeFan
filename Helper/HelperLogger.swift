import Foundation
import os.log

/// Wrappers around `os.Logger` for the helper. Categories show in Console.app.
public enum HelperLogger {
    public static let control  = Logger(subsystem: "com.breezefan.helper", category: "control")
    public static let safety   = Logger(subsystem: "com.breezefan.helper", category: "safety")
    public static let xpc      = Logger(subsystem: "com.breezefan.helper", category: "xpc")
    public static let smc      = Logger(subsystem: "com.breezefan.helper", category: "smc")
    public static let sensors  = Logger(subsystem: "com.breezefan.helper", category: "sensors")
}

extension Logger {
    func warn(_ msg: String) {
        self.warning("\(msg, privacy: .public)")
    }
    func log(_ msg: String) {
        self.info("\(msg, privacy: .public)")
    }
}
