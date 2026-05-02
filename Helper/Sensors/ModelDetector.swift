import Foundation
import IOKit

/// Reads the hardware model identifier from `IOPlatformExpertDevice`.
/// Lives in Helper because root privileges may make IOKit calls more reliable;
/// also keeps the App sandboxed-clean.
enum ModelDetector {
    /// The single model identifier the MVP supports.
    static let supportedModel = "MacBookPro18,3"

    /// Reads `model` property from `IOPlatformExpertDevice`. Returns the raw
    /// identifier (e.g. "MacBookPro18,3"). Returns "" on failure.
    static var current: String = {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(service) }
        guard service != 0 else { return "" }

        guard let model = IORegistryEntryCreateCFProperty(
            service,
            "model" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Data else {
            return ""
        }

        // The value is a NUL-terminated C string in the Data.
        if let str = String(data: model, encoding: .utf8) {
            return str.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
        return ""
    }()

    static func isSupported(model: String) -> Bool {
        model == supportedModel
    }
}
