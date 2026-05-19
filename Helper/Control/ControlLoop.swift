import Foundation

/// Main control loop. Ticks every 1.5s; reads sensors -> applies hysteresis -> interpolates curve
/// -> writes F0Md=1, F0Tg, F1Md=1, F1Tg. Idempotent F0Md write defends against macOS reclaiming control.
public final class ControlLoop: @unchecked Sendable {
    public let smcWriter: SMCWriting
    public let smcReader: SMCReading
    public let hysteresis: Hysteresis
    public let safety: SafetyOverride
    public let snapshotProvider: () -> SensorSnapshot
    public let configProvider: () -> ControlConfig
    public let f0Mn: Int
    public let f0Mx: Int
    public let f1Mn: Int
    public let f1Mx: Int
    public let intervalNanos: UInt64

    public private(set) var lastTickTimestamp: Date = Date()
    private var task: Task<Void, Never>?
    private var cancelled: Bool = false

    /// Serializes any SMC write originating from this loop. Held by `tick()`
    /// and `revertToAuto()`. Prevents the race where a `setMode(.auto)` calls
    /// `stop()` + `revertToAuto()` while a tick is mid-execution — without the
    /// lock the tick would write `F0Md=1` *after* the revert wrote `F0Md=0`,
    /// leaving fans stuck in manual mode. The watchdog cannot recover this
    /// because `isActive` is already false post-stop.
    private let writeLock = NSLock()

    /// True when the loop has been started and is actively running.
    public var isActive: Bool { task != nil && !cancelled }

    public init(
        smcReader: SMCReading,
        smcWriter: SMCWriting,
        hysteresis: Hysteresis = Hysteresis(),
        safety: SafetyOverride = SafetyOverride(),
        f0Mn: Int = 1300,
        f0Mx: Int = 6500,
        f1Mn: Int = 1300,
        f1Mx: Int = 6500,
        intervalSeconds: Double = 1.5,
        snapshotProvider: @escaping () -> SensorSnapshot,
        configProvider: @escaping () -> ControlConfig
    ) {
        self.smcReader = smcReader
        self.smcWriter = smcWriter
        self.hysteresis = hysteresis
        self.safety = safety
        self.f0Mn = f0Mn
        self.f0Mx = f0Mx
        self.f1Mn = f1Mn
        self.f1Mx = f1Mx
        self.intervalNanos = UInt64(intervalSeconds * 1_000_000_000)
        self.snapshotProvider = snapshotProvider
        self.configProvider = configProvider
    }

    public func start() {
        if task != nil { return }
        cancelled = false
        task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !self.cancelled, !Task.isCancelled {
                self.tick()
                try? await Task.sleep(nanoseconds: self.intervalNanos)
            }
        }
    }

    public func stop() {
        cancelled = true
        task?.cancel()
        task = nil
    }

    /// Single iteration. Public so tests can drive it deterministically.
    ///
    /// The `cancelled` check is **inside** `writeLock` so that a concurrent
    /// `revertToAuto()` (which also takes the lock) cannot be undone by an
    /// in-flight tick. Sequence: setMode flips `cancelled`, then waits on the
    /// lock, runs revert, releases. Pending tick acquires lock, sees
    /// `cancelled=true`, exits without writing.
    public func tick() {
        writeLock.lock()
        defer { writeLock.unlock() }
        if cancelled { return }
        lastTickTimestamp = Date()
        let cfg = configProvider()
        switch cfg.modeKind {
        case .auto:
            // Don't write — system handles fans.
            return
        case .forced:
            applyForced(cfg.forcedTargetRPM)
        case .curve:
            applyCurve(cfg.activeCurve)
        }
    }

    // MARK: - Mode appliers

    private func applyForced(_ rpm: Int?) {
        guard let rpm else { return }
        let snap = snapshotProvider()
        let safetyState = safety.tick(temp: snap.cpuTemp)
        let target0 = safetyState == .override ? f0Mx : clampRPM(rpm, mn: f0Mn, mx: f0Mx)
        let target1 = safetyState == .override ? f1Mx : clampRPM(rpm, mn: f1Mn, mx: f1Mx)
        write(target0: target0, target1: target1)
    }

    private func applyCurve(_ curve: Curve?) {
        guard let curve else { return }
        let snap = snapshotProvider()
        let safetyState = safety.tick(temp: snap.cpuTemp)

        if safetyState == .override {
            HelperLogger.safety.warn("SAFETY: temp \(snap.cpuTemp ?? .nan)°C exceeded threshold, forcing max RPM")
            write(target0: f0Mx, target1: f1Mx)
            return
        }

        guard let raw = snap.cpuTemp else {
            HelperLogger.control.warn("Skipping tick — temp unavailable")
            // Maintain F0Md=1 so system doesn't reclaim control.
            _ = smcWriter.writeUInt8(.f0Md, value: 1)
            _ = smcWriter.writeUInt8(.f1Md, value: 1)
            return
        }
        let effective = hysteresis.apply(raw)
        let duty = CurveInterpolator.interpolate(temp: effective, curve: curve)
        let target0 = CurveInterpolator.dutyToRPM(duty: duty, mn: f0Mn, mx: f0Mx)
        let target1 = CurveInterpolator.dutyToRPM(duty: duty, mn: f1Mn, mx: f1Mx)
        write(target0: target0, target1: target1)
    }

    private func clampRPM(_ rpm: Int, mn: Int, mx: Int) -> Int {
        return min(max(rpm, mn), mx)
    }

    private func write(target0: Int, target1: Int) {
        // Idempotent re-write of F0Md=1/F1Md=1 — defends against macOS reclaiming control.
        let r1 = smcWriter.writeUInt8(.f0Md, value: 1)
        let r2 = smcWriter.write(.f0Tg, value: Double(target0))
        let r3 = smcWriter.writeUInt8(.f1Md, value: 1)
        let r4 = smcWriter.write(.f1Tg, value: Double(target1))
        if case .failure(let e) = r2 {
            HelperLogger.smc.warn("write F0Tg=\(target0) failed: \(String(describing: e))")
        }
        if case .failure(let e) = r4 {
            HelperLogger.smc.warn("write F1Tg=\(target1) failed: \(String(describing: e))")
        }
        _ = r1; _ = r3
        // Per-tick trace — emits only when debug logging is enabled; production no-op.
        HelperLogger.control.trace("tick F0Tg=\(target0) F1Tg=\(target1)")
    }

    /// Reverts both fans to system control. Guarded by `writeLock` so an
    /// in-flight `tick()` can't clobber the Md=0 writes with Md=1.
    public func revertToAuto() {
        writeLock.lock()
        defer { writeLock.unlock() }
        _ = smcWriter.writeUInt8(.f0Md, value: 0)
        _ = smcWriter.writeUInt8(.f1Md, value: 0)
    }
}
