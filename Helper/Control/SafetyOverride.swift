import Foundation

/// Safety override state machine. Activates when temp > 95°C for 3 consecutive ticks,
/// deactivates when temp < 92°C (3°C hysteresis).
public final class SafetyOverride: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case normal
        case override
    }

    public let activateThreshold: Double
    public let deactivateThreshold: Double
    public let consecutiveTicks: Int

    public private(set) var state: State = .normal
    private var consecutiveAbove: Int = 0

    public init(
        activateThreshold: Double = 95.0,
        deactivateThreshold: Double = 92.0,
        consecutiveTicks: Int = 3
    ) {
        self.activateThreshold = activateThreshold
        self.deactivateThreshold = deactivateThreshold
        self.consecutiveTicks = consecutiveTicks
    }

    /// Process one tick. Returns the post-tick state.
    @discardableResult
    public func tick(temp: Double?) -> State {
        guard let t = temp else {
            // Missing temp doesn't increment counter, but doesn't reset either.
            return state
        }

        // Strict greater-than: 95.0 itself does NOT count as "above".
        if t > activateThreshold {
            consecutiveAbove += 1
            if consecutiveAbove >= consecutiveTicks {
                state = .override
            }
        } else {
            consecutiveAbove = 0
        }

        // Deactivate when temp drops below hysteresis floor.
        if state == .override && t < deactivateThreshold {
            state = .normal
        }

        return state
    }

    public func reset() {
        state = .normal
        consecutiveAbove = 0
    }
}
