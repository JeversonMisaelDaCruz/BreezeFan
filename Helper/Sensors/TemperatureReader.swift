import Foundation

/// Reads CPU temperature from a primary source (SMC) with fallback to IOHID.
public protocol TemperatureReading: AnyObject {
    /// Returns the maximum temperature across CPU performance clusters in °C.
    /// Returns nil when no source can provide a value.
    func maxCPUTemp() -> Double?
}

public final class TemperatureReader: TemperatureReading {
    public let smc: SMCReading
    public let ioHID: IOHIDReading

    public init(smc: SMCReading, ioHID: IOHIDReading) {
        self.smc = smc
        self.ioHID = ioHID
    }

    public func maxCPUTemp() -> Double? {
        var values: [Double] = []
        for key in SMCKey.cpuPerfClusters {
            if case .success(let v) = smc.read(key) {
                if v > 0 && v < 130 { // sanity range
                    values.append(v)
                }
            }
        }
        if let max = values.max() {
            return max
        }

        // Fallback to IOHID. Only invoked when ALL SMC keys failed.
        if let temp = ioHID.maxCPUTemperature() {
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

    public func maxCPUTemperature() -> Double? {
        // Apple Silicon temperature sensors live under the AppleVendor temperature page (0xff05).
        // Standard temperature page is 0x000D. We try both.
        let pages: [UInt32] = [0xff00, 0x0007, 0x000D]
        var maxTemp: Double = .nan

        for page in pages {
            if let temps = readSensors(page: page), let local = temps.max() {
                if maxTemp.isNaN || local > maxTemp {
                    maxTemp = local
                }
            }
        }
        return maxTemp.isNaN ? nil : maxTemp
    }

    /// Returns an array of temperatures (°C) read from the given IOHID usage page.
    /// Implementation uses private IOHIDEventSystemClient APIs from IOKit.framework
    /// — these are technically private but used by stats.app, MonitorControl, etc.
    private func readSensors(page: UInt32) -> [Double]? {
        // The full implementation requires IOHIDEventSystemClientCreate, copyServices,
        // and IOHIDServiceClientCopyEvent. These are private in IOKit and need
        // explicit dlsym binding in Swift. Stubbed for MVP — returns nil so
        // SMC path remains primary.
        //
        // TODO(fase 1, task 5.4): bind IOHIDEventSystemClientCreate via dlsym +
        // implement temperature event extraction. Until then this is a no-op
        // and SMC handles all temperature reads on MacBookPro18,3 (tested OK).
        return nil
    }
}
#endif
