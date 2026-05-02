import Foundation

/// Monitors `ControlLoop.lastTickTimestamp`. If the loop hasn't ticked in 5s,
/// reverts F0Md/F1Md to 0 (giving control back to the OS) and restarts the loop.
public final class Watchdog: @unchecked Sendable {
    public let smcWriter: SMCWriting
    public let controlLoop: ControlLoop
    public let staleThreshold: TimeInterval
    public let checkInterval: TimeInterval

    private var task: Task<Void, Never>?
    private var cancelled: Bool = false

    public init(
        smcWriter: SMCWriting,
        controlLoop: ControlLoop,
        staleThreshold: TimeInterval = 5.0,
        checkInterval: TimeInterval = 2.0
    ) {
        self.smcWriter = smcWriter
        self.controlLoop = controlLoop
        self.staleThreshold = staleThreshold
        self.checkInterval = checkInterval
    }

    public func start() {
        if task != nil { return }
        cancelled = false
        let nanos = UInt64(checkInterval * 1_000_000_000)
        task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !self.cancelled, !Task.isCancelled {
                self.checkOnce()
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    public func stop() {
        cancelled = true
        task?.cancel()
        task = nil
    }

    /// Single check — public for tests. Returns true if recovery fired.
    @discardableResult
    public func checkOnce() -> Bool {
        // Only check liveness when the control loop is actually supposed to be running.
        // In Auto mode the loop is intentionally idle; the timestamp not advancing is expected.
        guard controlLoop.isActive else { return false }

        let age = Date().timeIntervalSince(controlLoop.lastTickTimestamp)
        if age > staleThreshold {
            HelperLogger.control.warn("WATCHDOG: control loop stalled for \(age)s, recovering")
            _ = smcWriter.writeUInt8(.f0Md, value: 0)
            _ = smcWriter.writeUInt8(.f1Md, value: 0)
            controlLoop.stop()
            controlLoop.start()
            return true
        }
        return false
    }
}
