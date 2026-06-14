import Foundation

public extension SensorSnapshot {
    /// Default age (seconds) after which a cached snapshot is considered stale.
    ///
    /// MUST exceed the sensor sampling interval (5s, see `SensorPoller`) plus slack so a
    /// healthy snapshot is never flagged stale merely because of the sampling cadence.
    static let defaultStaleThreshold: TimeInterval = 8.0

    /// Returns a copy marked `stale` when older than `threshold` relative to `now`.
    ///
    /// Pure logic — no clock access, no IO. `now` is injected so the rule is testable.
    /// An already-stale snapshot is returned unchanged.
    func markingStale(
        asOf now: Date,
        threshold: TimeInterval = SensorSnapshot.defaultStaleThreshold
    ) -> SensorSnapshot {
        if stale { return self }
        let age = now.timeIntervalSince(timestamp)
        guard age > threshold else { return self }
        return SensorSnapshot(
            leftRPM: leftRPM,
            rightRPM: rightRPM,
            leftDuty: leftDuty,
            rightDuty: rightDuty,
            cpuTemp: cpuTemp,
            timestamp: timestamp,
            stale: true,
            smcConflict: smcConflict
        )
    }
}
