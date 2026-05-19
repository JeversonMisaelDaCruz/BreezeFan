import Foundation

/// Reads CPU temperature from a primary source (SMC) with fallback to IOHID.
public protocol TemperatureReading: AnyObject {
    /// Returns the maximum temperature across CPU performance clusters in °C.
    /// Returns nil when no source can provide a value.
    func maxCPUTemp() -> Double?
}

public final class TemperatureReader: TemperatureReading {
    /// Plausible CPU temperature range in °C. Anything outside is considered a
    /// decoding artifact (key returned wrong byte width / wrong format).
    public static let plausibleRange: ClosedRange<Double> = -20.0...120.0

    public let smc: SMCReading
    public let ioHID: IOHIDReading

    public init(smc: SMCReading, ioHID: IOHIDReading) {
        self.smc = smc
        self.ioHID = ioHID
    }

    /// Reads each CPU performance cluster key, filters by plausible range,
    /// returns the max valid value. Falls back to IOHID only if every key is
    /// either errored or out-of-range.
    ///
    /// Hot path — called on every poll tick. Avoids array allocation by tracking
    /// the running max in a single Double.
    public func maxCPUTemp() -> Double? {
        var maxVal: Double = -.infinity
        for key in SMCKey.cpuPerfClusters {
            switch smc.read(key) {
            case .success(let v):
                if Self.plausibleRange.contains(v) {
                    if v > maxVal { maxVal = v }
                } else {
                    HelperLogger.sensors.warn(
                        "rejected out-of-range temp \(key.code)=\(String(format: "%.1f", v))°C"
                    )
                }
            case .failure:
                continue
            }
        }
        if maxVal.isFinite { return maxVal }

        if let temp = ioHID.maxCPUTemperature(), Self.plausibleRange.contains(temp) {
            return temp
        }

        return nil
    }
}

// MARK: - IOHID protocol + live impl

public protocol IOHIDReading: AnyObject {
    /// Returns the max temperature reported by IOHID temp sensors, in °C.
    /// nil if IOHID has no readable temperature sensors.
    func maxCPUTemperature() -> Double?
}

#if canImport(IOKit)
import IOKit.hid

public final class IOHIDReader: IOHIDReading {
    public init() {}

    /// IOHID fallback path — not yet implemented. The full implementation requires
    /// `IOHIDEventSystemClientCreate` + service iteration via private IOKit APIs
    /// (used by stats.app, MonitorControl, etc.) and `dlsym` binding in Swift.
    ///
    /// Until that lands (TODO fase 1, task 5.4), SMC handles every temperature read
    /// on MacBookPro18,3 — this method is a fast nil so the snapshot hot path doesn't
    /// pay for an iteration that always returns nil anyway.
    public func maxCPUTemperature() -> Double? {
        return nil
    }
}
#endif
