import SwiftUI
import Observation

/// Observable model that polls the helper for sensor snapshots and exposes them to SwiftUI.
@Observable
@MainActor
final class SensorViewModel {
    /// Last snapshot received.
    var snapshot: SensorSnapshot = .empty

    /// True while the polling task is running.
    var isPolling: Bool = false

    /// True after at least one successful XPC reply.
    var helperReachable: Bool = false

    /// Last error from the helper (for the offline banner).
    var lastError: String?

    private var task: Task<Void, Never>?

    /// Starts polling at 1Hz. Idempotent.
    func start() {
        guard task == nil else { return }
        isPolling = true
        task = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollOnce()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isPolling = false
    }

    func pollOnce() async {
        do {
            let snap = try await HelperClient.shared.getSnapshot()
            self.snapshot = snap
            let wasReachable = self.helperReachable
            self.helperReachable = true
            self.lastError = nil

            if !wasReachable || AppState.shared.fanCeilings == nil {
                await fetchCeilingsIfNeeded()
            }
        } catch {
            self.helperReachable = false
            self.lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            self.snapshot = SensorSnapshot(
                leftRPM: snapshot.leftRPM,
                rightRPM: snapshot.rightRPM,
                leftDuty: snapshot.leftDuty,
                rightDuty: snapshot.rightDuty,
                cpuTemp: snapshot.cpuTemp,
                timestamp: snapshot.timestamp,
                stale: true,
                smcConflict: snapshot.smcConflict
            )
            AppState.shared.fanCeilings = nil
        }
    }

    /// Fetches fan ceilings from helper if not yet cached. Idempotent.
    private func fetchCeilingsIfNeeded() async {
        guard AppState.shared.fanCeilings == nil else { return }
        do {
            let ceilings = try await HelperClient.shared.getFanCeilings()
            let m = "fetchCeilings: f0=\(ceilings.f0Mn)..\(ceilings.f0Mx) f1=\(ceilings.f1Mn)..\(ceilings.f1Mx) valid=\(ceilings.valid)"
            AppLogger.xpc.info("\(m, privacy: .public)")
            AppState.shared.fanCeilings = ceilings
        } catch {
            let m = "fetchCeilings: FAILED \(error)"
            AppLogger.xpc.info("\(m, privacy: .public)")
        }
    }

    var fanCount: Int {
        var count = 0
        if (snapshot.leftRPM ?? 0) > 0 { count += 1 }
        if (snapshot.rightRPM ?? 0) > 0 { count += 1 }
        return count
    }

    func subtext(unit: AppState.TempUnit) -> String {
        if !helperReachable {
            return "Helper offline"
        }
        let activeWord = "\(fanCount) fans active"
        guard let t = snapshot.cpuTemp else {
            return "Sensor unavailable · \(activeWord)"
        }
        let status: String
        switch t {
        case ..<60:  status = "Running cool"
        case 60..<80: status = "Warming up"
        default:      status = "Hot"
        }
        return "\(status) · \(activeWord)"
    }
}
