import Foundation

/// 3°C bidirectional hysteresis. Applied to the temp before curve interpolation.
/// Up moves are immediate; down moves require >= `dropThreshold` °C below the last effective.
public final class Hysteresis: @unchecked Sendable {
    public let dropThreshold: Double
    public private(set) var lastEffective: Double

    public init(initialTemp: Double = 50.0, dropThreshold: Double = 3.0) {
        self.lastEffective = initialTemp
        self.dropThreshold = dropThreshold
    }

    /// Apply hysteresis to the current measurement and return the effective temp.
    @discardableResult
    public func apply(_ current: Double) -> Double {
        if current >= lastEffective {
            // Up — accept immediately.
            lastEffective = current
        } else if current <= lastEffective - dropThreshold {
            // Down ≥ threshold — accept.
            lastEffective = current
        }
        // Otherwise: stay put.
        return lastEffective
    }
}
