import Foundation

/// Snapshot returned by the helper on every `getSnapshot()` poll. JSON-encoded over XPC.
public struct SensorSnapshot: Codable, Sendable, Equatable {
    public let leftRPM: Int?
    public let rightRPM: Int?
    public let leftDuty: Double?
    public let rightDuty: Double?
    public let cpuTemp: Double?
    public let timestamp: Date
    public let stale: Bool
    public let smcConflict: Bool

    public init(
        leftRPM: Int?,
        rightRPM: Int?,
        leftDuty: Double?,
        rightDuty: Double?,
        cpuTemp: Double?,
        timestamp: Date,
        stale: Bool,
        smcConflict: Bool
    ) {
        self.leftRPM = leftRPM
        self.rightRPM = rightRPM
        self.leftDuty = leftDuty
        self.rightDuty = rightDuty
        self.cpuTemp = cpuTemp
        self.timestamp = timestamp
        self.stale = stale
        self.smcConflict = smcConflict
    }

    public static let empty = SensorSnapshot(
        leftRPM: nil, rightRPM: nil,
        leftDuty: nil, rightDuty: nil,
        cpuTemp: nil,
        timestamp: Date(timeIntervalSince1970: 0),
        stale: true,
        smcConflict: false
    )

    /// Number of fans reporting non-zero RPM. Computed once at the type level so
    /// the App and the menu bar don't each implement the same arithmetic.
    public var activeFanCount: Int {
        var n = 0
        if (leftRPM ?? 0) > 0 { n += 1 }
        if (rightRPM ?? 0) > 0 { n += 1 }
        return n
    }
}

/// Three control modes, mutually exclusive. Persisted in `control.json`.
public enum ControlMode: Codable, Sendable, Equatable {
    case auto
    case forced(rpm: Int)
    case curve

    public enum Kind: String, Codable, Sendable {
        case auto, forced, curve
    }

    public var kind: Kind {
        switch self {
        case .auto: return .auto
        case .forced: return .forced
        case .curve: return .curve
        }
    }
}

/// One step of a fan curve: target duty (%) at a given temperature (°C).
public struct CurveStep: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var temp: Int
    public var duty: Int
    public var id: Int { temp * 1000 + duty }

    public init(temp: Int, duty: Int) {
        self.temp = temp
        self.duty = duty
    }
}

/// Fan curve. 2-6 steps, ordered by temp ascending, no duplicate temps.
public struct Curve: Codable, Sendable, Equatable {
    public var steps: [CurveStep]

    public init(steps: [CurveStep]) {
        self.steps = steps
    }

    public static let `default` = Curve(steps: [
        CurveStep(temp: 40, duty: 20),
        CurveStep(temp: 60, duty: 50),
        CurveStep(temp: 75, duty: 80),
        CurveStep(temp: 90, duty: 100),
    ])
}

public enum CurveError: Error, Equatable, Sendable {
    case tooFewSteps
    case tooManySteps
    case unordered
    case duplicateTemp
    case invalidTempRange(temp: Int)
    case invalidDutyRange(duty: Int)
}

/// Named MVP presets. Mapping is in `Preset.targetMode(f0Mx:f1Mx:)`.
public enum Preset: String, Codable, Sendable, CaseIterable, Identifiable {
    case silent
    case balanced
    case performance
    case max

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .silent:      return "Silent"
        case .balanced:    return "Balanced"
        case .performance: return "Performance"
        case .max:         return "Max"
        }
    }

    /// Computes the SMC target mode for this preset given the hardware ceilings.
    /// - Parameters:
    ///   - f0Mx: max RPM of fan 0 (Left), e.g. 6500 on MacBookPro18,3
    ///   - f1Mx: max RPM of fan 1 (Right)
    public func targetMode(f0Mx: Int, f1Mx: Int) -> ControlMode {
        switch self {
        case .silent:
            // Spec: 35% of f0Mx, with helper clamping to f0Mn at write time.
            let target = Int(Double(f0Mx) * 0.35)
            return .forced(rpm: target)
        case .balanced:
            return .auto
        case .performance:
            let target = Int(Double(f0Mx) * 0.70)
            return .forced(rpm: target)
        case .max:
            return .forced(rpm: f0Mx)
        }
    }
}

/// Helper-side error envelope; all XPC failures carry one.
public enum HelperError: Error, Codable, Equatable, Sendable, LocalizedError {
    case notInstalled
    case smcLocked
    case smcUnavailable
    case unsupportedModel(String)
    case invalidPayload
    case invalidCurve(reason: String)
    case ioError(message: String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled:           return "Helper is not installed."
        case .smcLocked:              return "SMC is locked by another process."
        case .smcUnavailable:         return "SMC service is unavailable."
        case .unsupportedModel(let m):return "Unsupported hardware model: \(m)."
        case .invalidPayload:         return "XPC payload could not be decoded."
        case .invalidCurve(let r):    return "Invalid curve: \(r)"
        case .ioError(let m):         return "I/O error: \(m)"
        }
    }
}

/// Hardware capabilities advertised by the helper after probing the active
/// machine. The App uses this to decide which UI affordances to show
/// (e.g. hide the right-fan row on a 1-fan Mac, switch to "passive cooling"
/// mode on a fanless Air, gray out controls on an unrecognized model).
///
/// Returned by `HelperProtocol.getHardwareProfile`, JSON-encoded.
public struct HardwareCapabilities: Codable, Sendable, Equatable {
    /// `IOPlatformExpertDevice` model string — e.g. `"MacBookPro18,3"`.
    public let modelIdentifier: String

    /// Human-friendly name shown in the UI — e.g. `"MacBook Pro 14\" M1 Pro"`.
    public let displayName: String

    /// Number of fans the helper expects to read/write. `0` for fanless
    /// machines (MacBook Air), `1` for single-fan MacBook Pros, `2` for
    /// every Pro/Max class machine BreezeFan currently knows about.
    public let fanCount: Int

    /// True when the helper has a vetted profile for this model: SMC keys are
    /// known to be valid, fan ceilings are within the expected range, and the
    /// safety override has a temperature source to react to. False when the
    /// model is unrecognized or fanless — the App should treat the UI as
    /// read-only.
    public let controlSupported: Bool

    /// True when the SMC reader probed real temperature data from the keys
    /// in this profile. False means the IOHID fallback is the only source
    /// (or no source at all). UI may show a soft warning.
    public let temperatureSourceValid: Bool

    public init(
        modelIdentifier: String,
        displayName: String,
        fanCount: Int,
        controlSupported: Bool,
        temperatureSourceValid: Bool
    ) {
        self.modelIdentifier = modelIdentifier
        self.displayName = displayName
        self.fanCount = fanCount
        self.controlSupported = controlSupported
        self.temperatureSourceValid = temperatureSourceValid
    }

    /// Fallback when the helper isn't installed / unreachable. App defaults to
    /// a conservative read-only stance until live data arrives.
    public static let unknown = HardwareCapabilities(
        modelIdentifier: "",
        displayName: "Detecting hardware…",
        fanCount: 0,
        controlSupported: false,
        temperatureSourceValid: false
    )
}

/// Hardware fan ceilings reported by the helper after SMC boot read.
/// `valid` is true when all four readings fell within the plausible range
/// (Mn ∈ [500, 3000], Mx ∈ [3500, 10000]). Otherwise the helper used safe
/// defaults (1300/6500) and the app should treat presets cautiously.
public struct FanCeilings: Codable, Sendable, Equatable {
    public let f0Mn: Int
    public let f0Mx: Int
    public let f1Mn: Int
    public let f1Mx: Int
    public let valid: Bool

    public init(f0Mn: Int, f0Mx: Int, f1Mn: Int, f1Mx: Int, valid: Bool) {
        self.f0Mn = f0Mn
        self.f0Mx = f0Mx
        self.f1Mn = f1Mn
        self.f1Mx = f1Mx
        self.valid = valid
    }

    public static let defaults = FanCeilings(
        f0Mn: 1300, f0Mx: 6500, f1Mn: 1300, f1Mx: 6500, valid: false
    )

    /// Range constraints used to validate readings.
    public static let mnRange: ClosedRange<Int> = 500...3000
    public static let mxRange: ClosedRange<Int> = 3500...10000

    public static func validate(f0Mn: Int, f0Mx: Int, f1Mn: Int, f1Mx: Int) -> Bool {
        mnRange.contains(f0Mn)
            && mxRange.contains(f0Mx)
            && mnRange.contains(f1Mn)
            && mxRange.contains(f1Mx)
            && f0Mn < f0Mx
            && f1Mn < f1Mx
    }
}

/// Persisted config for the helper. Lives at /Library/Application Support/BreezeFan/control.json.
public struct ControlConfig: Codable, Sendable, Equatable {
    public var version: Int
    public var modeKind: ControlMode.Kind
    public var forcedTargetRPM: Int?
    public var activeCurve: Curve?
    public var updatedAt: Date

    public init(
        version: Int = 1,
        modeKind: ControlMode.Kind = .auto,
        forcedTargetRPM: Int? = nil,
        activeCurve: Curve? = nil,
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.modeKind = modeKind
        self.forcedTargetRPM = forcedTargetRPM
        self.activeCurve = activeCurve
        self.updatedAt = updatedAt
    }

    public var resolvedMode: ControlMode {
        switch modeKind {
        case .auto:   return .auto
        case .forced: return .forced(rpm: forcedTargetRPM ?? 0)
        case .curve:  return .curve
        }
    }

    public static let defaults = ControlConfig()
}
