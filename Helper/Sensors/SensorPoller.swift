import Foundation

/// Polls the SMC at a fixed interval (5s by default) and caches the latest snapshot.
///
/// The cadence is intentionally slow (was 1s) to cut background CPU wakeups. Thermal
/// safety is unaffected: the control loop ticks far faster (1.5s) and reacts to the most
/// recent cached reading — see `ControlLoop` / `SafetyOverride`.
public final class SensorPoller: @unchecked Sendable {
    private let builder: SnapshotBuilder
    private let intervalNanos: UInt64
    private let lock = NSLock()
    private var lastSnapshot: SensorSnapshot = .empty
    private var pollingTask: Task<Void, Never>?

    public init(builder: SnapshotBuilder, intervalSeconds: Double = 5.0) {
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

    /// Returns the cached snapshot, marking it stale if older than the stale threshold (8s).
    ///
    /// The threshold must exceed the 5s sampling interval plus slack so a healthy snapshot
    /// is never flagged stale just because of the slower cadence. Stale-marking is pure
    /// logic in `SensorSnapshot.markingStale(asOf:threshold:)` (Shared) so it is unit-tested
    /// without the SMC mock chain.
    public func latest() -> SensorSnapshot {
        lock.lock()
        let snap = lastSnapshot
        lock.unlock()
        return snap.markingStale(asOf: Date())
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
