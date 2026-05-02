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

    /// Stops polling. Used when the window goes inactive.
    func stop() {
        task?.cancel()
        task = nil
        isPolling = false
    }

    /// Triggers a single poll immediately. Used when the app comes back to foreground.
    func pollOnce() async {
        do {
            let snap = try await HelperClient.shared.getSnapshot()
            self.snapshot = snap
        } catch {
            // Helper unreachable — keep last snapshot but mark stale.
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
        }
    }

    // MARK: - Derived view state

    var fanCount: Int {
        var count = 0
        if (snapshot.leftRPM ?? 0) > 0 { count += 1 }
        if (snapshot.rightRPM ?? 0) > 0 { count += 1 }
        return count
    }

    /// Subtext below the temp readout.
    func subtext(unit: AppState.TempUnit) -> String {
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
