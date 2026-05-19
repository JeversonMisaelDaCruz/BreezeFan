import Foundation
import IOKit

/// Reads the hardware model identifier from `IOPlatformExpertDevice` and
/// resolves it against the `ModelProfile` registry.
///
/// Lives in Helper because root privileges may make IOKit calls more reliable;
/// also keeps the App sandboxed-clean.
enum ModelDetector {
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

    /// Resolved profile for the running machine. Cached at first access.
    static var currentProfile: ModelProfile = {
        let id = current
        return ModelProfile.known(for: id)
            ?? ModelProfile.defensiveUnknown(identifier: id)
    }()

    /// Returns true if the running model has a vetted control profile —
    /// i.e. the helper can safely write F0Md/F1Md/F0Tg/F1Tg.
    static func isSupported(model: String) -> Bool {
        ModelProfile.known(for: model)?.controlSupported ?? false
    }
}
