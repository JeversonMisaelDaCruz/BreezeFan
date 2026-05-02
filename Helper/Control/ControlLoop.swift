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
    public func tick() {
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
        _ = smcWriter.writeUInt8(.f0Md, value: 1)
        _ = smcWriter.write(.f0Tg, value: Double(target0))
        _ = smcWriter.writeUInt8(.f1Md, value: 1)
        _ = smcWriter.write(.f1Tg, value: Double(target1))
    }

    /// Reverts both fans to system control.
    public func revertToAuto() {
        _ = smcWriter.writeUInt8(.f0Md, value: 0)
        _ = smcWriter.writeUInt8(.f1Md, value: 0)
    }
}
