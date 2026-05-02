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

/// Persisted config for the helper. Lives at /Library/Application Support/FanControl/control.json.
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
