import Foundation

/// Orchestrates mode transitions: persists to control.json + drives ControlLoop start/stop.
/// All exposed methods are synchronous; underlying actors handle async safely.
public final class ModeManager: ModeManaging, @unchecked Sendable {
    public let store: ControlConfigStore
    public let smcWriter: SMCWriting
    public let controlLoop: ControlLoop
    public let f0Mx: Int
    public let f1Mx: Int

    private let lock = NSLock()

    public init(
        store: ControlConfigStore,
        smcWriter: SMCWriting,
        controlLoop: ControlLoop,
        f0Mx: Int,
        f1Mx: Int
    ) {
        self.store = store
        self.smcWriter = smcWriter
        self.controlLoop = controlLoop
        self.f0Mx = f0Mx
        self.f1Mx = f1Mx
    }

    public func setMode(_ mode: ControlMode) throws {
        lock.lock(); defer { lock.unlock() }
        var cfg = store.load()
        cfg.modeKind = mode.kind
        switch mode {
        case .auto:
            controlLoop.stop()
            controlLoop.revertToAuto()
            cfg.forcedTargetRPM = nil
            HelperLogger.control.log("setMode -> auto")
        case .forced(let rpm):
            cfg.forcedTargetRPM = rpm
            controlLoop.start()
            HelperLogger.control.log("setMode -> forced(\(rpm))")
        case .curve:
            controlLoop.start()
            HelperLogger.control.log("setMode -> curve")
        }
        try store.save(cfg)
    }

    public func setCurve(_ curve: Curve) throws {
        lock.lock(); defer { lock.unlock() }
        var cfg = store.load()
        cfg.activeCurve = curve
        cfg.modeKind = .curve
        try store.save(cfg)
        controlLoop.start()
        HelperLogger.control.log("setCurve — \(curve.steps.count) steps")
    }

    public func applyPreset(_ preset: Preset) throws {
        let mode = preset.targetMode(f0Mx: f0Mx, f1Mx: f1Mx)
        try setMode(mode)
    }

    public func uninstall() throws {
        lock.lock(); defer { lock.unlock() }
        controlLoop.stop()
        controlLoop.revertToAuto()
        store.remove()
        HelperLogger.control.log("uninstall — control.json removed, fans back to Auto")
    }
}
