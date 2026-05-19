import Foundation

/// Per-model SMC topology. The helper consults this on boot to decide which
/// temperature keys to read, how many fans to address, and whether to allow
/// fan control at all on the running hardware.
///
/// Keys here were sourced from:
/// - Apple's `applesmc.h` for the legacy fan key layout
/// - macsfancontrol / iStat Menus community SMC dumps for Apple Silicon
///   temperature key namespaces
/// - First-party verification on `MacBookPro18,3` (the original target model)
///
/// **Adding a new model:** append an entry to `knownProfiles`. If you don't
/// have a verified SMC key list for the family yet, leave `controlSupported`
/// false and `tempKeys` empty so the App enters read-only mode rather than
/// pretending to control fans without temperature feedback.
struct ModelProfile {
    let identifier: String
    let displayName: String
    let fanCount: Int
    let tempKeys: [SMCKey]
    let controlSupported: Bool

    /// Lookup by exact `IOPlatformExpertDevice/model` string.
    /// Returns `nil` when the model isn't in the registry — the caller falls
    /// back to a defensive read-only profile.
    static func known(for modelIdentifier: String) -> ModelProfile? {
        knownProfiles[modelIdentifier]
    }

    /// Conservative profile for an unknown machine: zero fans, read-only,
    /// no temperature keys. The helper still serves snapshots (IOHID may
    /// provide a temp value) but rejects any setMode/setCurve attempt.
    static func defensiveUnknown(identifier: String) -> ModelProfile {
        ModelProfile(
            identifier: identifier,
            displayName: identifier.isEmpty ? "Unknown Mac" : identifier,
            fanCount: 0,
            tempKeys: [],
            controlSupported: false
        )
    }

    /// Renders the snapshot exposed to the App.
    func capabilities(temperatureSourceValid: Bool) -> HardwareCapabilities {
        HardwareCapabilities(
            modelIdentifier: identifier,
            displayName: displayName,
            fanCount: fanCount,
            controlSupported: controlSupported,
            temperatureSourceValid: temperatureSourceValid
        )
    }

    // MARK: - Registry

    /// M1 Pro / Max performance-cluster temperature keys. Verified on
    /// `MacBookPro18,3`. Apple Silicon laptops in this family share the
    /// same fan SMC layout (`F{0,1}{Ac,Md,Mn,Mx,Tg}`).
    private static let m1ProMaxTempKeys: [SMCKey] = [
        .tp01, .tp05, .tp09, .tp0D, .tp0H,
    ]

    /// Two-fan Apple Silicon Pro/Max class. Keys are identical across M1
    /// variants (18,1 / 18,2 / 18,3 / 18,4).
    private static func m1ProMaxProfile(
        identifier: String, displayName: String
    ) -> ModelProfile {
        ModelProfile(
            identifier: identifier,
            displayName: displayName,
            fanCount: 2,
            tempKeys: m1ProMaxTempKeys,
            controlSupported: true
        )
    }

    /// Fanless MacBook Air profile. Temperature monitoring only; SMC fan
    /// writes are rejected upstream by `controlSupported == false`.
    private static func airProfile(
        identifier: String, displayName: String
    ) -> ModelProfile {
        ModelProfile(
            identifier: identifier,
            displayName: displayName,
            fanCount: 0,
            tempKeys: m1ProMaxTempKeys, // Same Tp* family on Apple Silicon Air
            controlSupported: false
        )
    }

    static let knownProfiles: [String: ModelProfile] = [
        // MacBook Pro M1 Pro / Max (2021)
        "MacBookPro18,1": m1ProMaxProfile(identifier: "MacBookPro18,1",
                                          displayName: "MacBook Pro 16\" M1 Pro/Max"),
        "MacBookPro18,2": m1ProMaxProfile(identifier: "MacBookPro18,2",
                                          displayName: "MacBook Pro 16\" M1 Max"),
        "MacBookPro18,3": m1ProMaxProfile(identifier: "MacBookPro18,3",
                                          displayName: "MacBook Pro 14\" M1 Pro/Max"),
        "MacBookPro18,4": m1ProMaxProfile(identifier: "MacBookPro18,4",
                                          displayName: "MacBook Pro 14\" M1 Max"),

        // MacBook Air M1 / M2 / M3 — fanless, monitoring only
        "MacBookAir10,1": airProfile(identifier: "MacBookAir10,1",
                                     displayName: "MacBook Air M1"),
        "Mac14,2":        airProfile(identifier: "Mac14,2",
                                     displayName: "MacBook Air M2"),
        "Mac14,15":       airProfile(identifier: "Mac14,15",
                                     displayName: "MacBook Air 15\" M2"),
        "Mac15,12":       airProfile(identifier: "Mac15,12",
                                     displayName: "MacBook Air M3"),
        "Mac15,13":       airProfile(identifier: "Mac15,13",
                                     displayName: "MacBook Air 15\" M3"),
    ]
}
