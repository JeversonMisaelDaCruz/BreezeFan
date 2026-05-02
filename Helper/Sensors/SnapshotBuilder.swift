import Foundation

/// Constructs `SensorSnapshot` from raw SMC + temperature readings. Pure logic — no IO scheduling.
public final class SnapshotBuilder {
    public let smc: SMCReading
    public let temp: TemperatureReading

    /// Cached fan ceilings, populated on boot and validated against a plausible range.
    public var f0Mn: Int = 1300
    public var f0Mx: Int = 6500
    public var f1Mn: Int = 1300
    public var f1Mx: Int = 6500

    /// True when all 4 ceiling reads fell within the plausible range.
    /// False when any reading was rejected — defaults are used in that case.
    public var ceilingsValid: Bool = false

    /// True when the last write attempt failed with `kIOReturnExclusiveAccess`.
    public var smcConflict: Bool = false

    /// Tick counter — used by diagnostic logging in the first 5 ticks after boot.
    public var tickCount: Int = 0

    public init(smc: SMCReading, temp: TemperatureReading) {
        self.smc = smc
        self.temp = temp
        loadFanCeilings()
    }

    public func loadFanCeilings() {
        var rawF0Mn: Int?
        var rawF0Mx: Int?
        var rawF1Mn: Int?
        var rawF1Mx: Int?

        if case .success(let v) = smc.read(.f0Mn) { rawF0Mn = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f0Mx) { rawF0Mx = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f1Mn) { rawF1Mn = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f1Mx) { rawF1Mx = Int(v.rounded()) }

        let f0MnVal = rawF0Mn ?? 1300
        let f0MxVal = rawF0Mx ?? 6500
        let f1MnVal = rawF1Mn ?? 1300
        let f1MxVal = rawF1Mx ?? 6500

        let valid = FanCeilings.validate(
            f0Mn: f0MnVal, f0Mx: f0MxVal,
            f1Mn: f1MnVal, f1Mx: f1MxVal
        )

        if valid {
            f0Mn = f0MnVal; f0Mx = f0MxVal
            f1Mn = f1MnVal; f1Mx = f1MxVal
            ceilingsValid = true
            HelperLogger.smc.log("loadFanCeilings: F0=\(f0Mn)..\(f0Mx) F1=\(f1Mn)..\(f1Mx) (valid)")
        } else {
            // Keep defaults; flag invalid.
            ceilingsValid = false
            let detail = "F0Mn=\(f0MnVal) F0Mx=\(f0MxVal) F1Mn=\(f1MnVal) F1Mx=\(f1MxVal)"
            HelperLogger.smc.warn("loadFanCeilings: \(detail) out of plausible range — using defaults 1300/6500")
        }
    }

    /// Returns a snapshot of fan ceilings as the Codable struct used over XPC.
    public var ceilings: FanCeilings {
        FanCeilings(
            f0Mn: f0Mn, f0Mx: f0Mx,
            f1Mn: f1Mn, f1Mx: f1Mx,
            valid: ceilingsValid
        )
    }

    public func build() -> SensorSnapshot {
        tickCount += 1
        let isDiagTick = tickCount <= 5
        var conflict = smcConflict
        let leftRPM: Int? = {
            switch smc.read(.f0Ac) {
            case .success(let v):
                let val = Int(v.rounded())
                if isDiagTick {
                    HelperLogger.smc.log("smc tick=\(self.tickCount) key=F0Ac decoded=\(val) RPM")
                }
                return val
            case .failure(.locked):
                conflict = true
                if isDiagTick { HelperLogger.smc.warn("smc tick=\(self.tickCount) key=F0Ac error=locked") }
                return nil
            case .failure(let err):
                if isDiagTick { HelperLogger.smc.warn("smc tick=\(self.tickCount) key=F0Ac error=\(err)") }
                return nil
            }
        }()
        let rightRPM: Int? = {
            switch smc.read(.f1Ac) {
            case .success(let v):
                let val = Int(v.rounded())
                if isDiagTick {
                    HelperLogger.smc.log("smc tick=\(self.tickCount) key=F1Ac decoded=\(val) RPM")
                }
                return val
            case .failure(.locked):
                conflict = true
                if isDiagTick { HelperLogger.smc.warn("smc tick=\(self.tickCount) key=F1Ac error=locked") }
                return nil
            case .failure(let err):
                if isDiagTick { HelperLogger.smc.warn("smc tick=\(self.tickCount) key=F1Ac error=\(err)") }
                return nil
            }
        }()

        let cpuTemp = temp.maxCPUTemp()

        let leftDuty  = duty(rpm: leftRPM,  mn: f0Mn, mx: f0Mx)
        let rightDuty = duty(rpm: rightRPM, mn: f1Mn, mx: f1Mx)

        return SensorSnapshot(
            leftRPM: leftRPM,
            rightRPM: rightRPM,
            leftDuty: leftDuty,
            rightDuty: rightDuty,
            cpuTemp: cpuTemp,
            timestamp: Date(),
            stale: false,
            smcConflict: conflict
        )
    }

    /// duty = (rpm - mn) / (mx - mn), clamped 0…1, returns nil when rpm is nil.
    private func duty(rpm: Int?, mn: Int, mx: Int) -> Double? {
        guard let rpm else { return nil }
        let span = mx - mn
        guard span > 0 else { return 0 }
        let d = Double(rpm - mn) / Double(span)
        return min(max(d, 0), 1)
    }
}
