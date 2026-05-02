import Foundation

/// Polls the SMC at a fixed interval and caches the latest snapshot.
public final class SensorPoller: @unchecked Sendable {
    private let builder: SnapshotBuilder
    private let intervalNanos: UInt64
    private let lock = NSLock()
    private var lastSnapshot: SensorSnapshot = .empty
    private var pollingTask: Task<Void, Never>?

    public init(builder: SnapshotBuilder, intervalSeconds: Double = 1.0) {
        self.builder = builder
        self.intervalNanos = UInt64(intervalSeconds * 1_000_000_000)
    }

    /// Starts the polling loop. Idempotent.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        if pollingTask != nil { return }
        let interval = intervalNanos
        pollingTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                self?.runOnce()
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    public func stop() {
        lock.lock()
        let task = pollingTask
        pollingTask = nil
        lock.unlock()
        task?.cancel()
    }

    /// Reads the SMC once and stores the snapshot. Returns the new snapshot.
    @discardableResult
    public func runOnce() -> SensorSnapshot {
        let snap = builder.build()
        lock.lock()
        lastSnapshot = snap
        lock.unlock()
        return snap
    }

    /// Returns the cached snapshot, marking it stale if older than 3s.
    public func latest() -> SensorSnapshot {
        lock.lock()
        let snap = lastSnapshot
        lock.unlock()
        let age = Date().timeIntervalSince(snap.timestamp)
        if age > 3.0 {
            return SensorSnapshot(
                leftRPM: snap.leftRPM,
                rightRPM: snap.rightRPM,
                leftDuty: snap.leftDuty,
                rightDuty: snap.rightDuty,
                cpuTemp: snap.cpuTemp,
                timestamp: snap.timestamp,
                stale: true,
                smcConflict: snap.smcConflict
            )
        }
        return snap
    }
}

/// Adapter conforming `SensorPolling` (sync interface for HelperService).
final class SensorPollingAdapter: SensorPolling {
    let poller: SensorPoller

    init(poller: SensorPoller) {
        self.poller = poller
    }

    func latestSnapshot() -> SensorSnapshot {
        poller.latest()
    }

    func startPump() {
        poller.start()
    }
}
