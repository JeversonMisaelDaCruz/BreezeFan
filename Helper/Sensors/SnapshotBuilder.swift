import Foundation

/// Constructs `SensorSnapshot` from raw SMC + temperature readings. Pure logic — no IO scheduling.
public final class SnapshotBuilder {
    public let smc: SMCReading
    public let temp: TemperatureReading

    /// Cached fan ceilings, populated on boot.
    public var f0Mn: Int = 1300
    public var f0Mx: Int = 6500
    public var f1Mn: Int = 1300
    public var f1Mx: Int = 6500

    /// True when the last write attempt failed with `kIOReturnExclusiveAccess`.
    public var smcConflict: Bool = false

    public init(smc: SMCReading, temp: TemperatureReading) {
        self.smc = smc
        self.temp = temp
        loadFanCeilings()
    }

    public func loadFanCeilings() {
        if case .success(let v) = smc.read(.f0Mn) { f0Mn = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f0Mx) { f0Mx = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f1Mn) { f1Mn = Int(v.rounded()) }
        if case .success(let v) = smc.read(.f1Mx) { f1Mx = Int(v.rounded()) }
    }

    public func build() -> SensorSnapshot {
        var conflict = smcConflict
        let leftRPM: Int? = {
            switch smc.read(.f0Ac) {
            case .success(let v): return Int(v.rounded())
            case .failure(.locked): conflict = true; return nil
            case .failure: return nil
            }
        }()
        let rightRPM: Int? = {
            switch smc.read(.f1Ac) {
            case .success(let v): return Int(v.rounded())
            case .failure(.locked): conflict = true; return nil
            case .failure: return nil
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
