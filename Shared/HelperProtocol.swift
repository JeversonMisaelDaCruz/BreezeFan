import Foundation

/// XPC protocol shared between BreezeFan.app (sandbox) and BreezeFanHelper (root daemon).
///
/// Bridge to Objective-C is required because NSXPCInterface only accepts @objc protocols.
/// Codable Swift types are passed via NSSecureCoding-compatible payload (Data wrapping JSON).
@objc public protocol HelperProtocol {
    /// Round-trip latency probe. Helper replies with `Date()` so the app can measure liveness.
    func ping(reply: @escaping (Date) -> Void)

    /// Returns the latest sensor snapshot. JSON-encoded SensorSnapshot inside Data.
    func getSnapshot(reply: @escaping (Data?, Error?) -> Void)

    /// Sets the active control mode. JSON-encoded ControlMode inside `modeData`.
    func setMode(_ modeData: Data, reply: @escaping (Bool, Error?) -> Void)

    /// Replaces the active fan curve. JSON-encoded Curve inside `curveData`.
    func setCurve(_ curveData: Data, reply: @escaping (Bool, Error?) -> Void)

    /// Applies one of the named MVP presets. Raw value of `Preset` enum.
    func applyPreset(_ presetRawValue: String, reply: @escaping (Bool, Error?) -> Void)

    /// Returns hardware model identifier (e.g. "MacBookPro18,3") and `readOnly` flag.
    /// Legacy — prefer `getHardwareProfile` which carries fanCount + displayName.
    func getModelInfo(reply: @escaping (String, Bool) -> Void)

    /// Returns the active `HardwareCapabilities` for the running Mac
    /// (model identifier, display name, fan count, controlSupported flag,
    /// temperatureSourceValid). JSON-encoded inside Data.
    func getHardwareProfile(reply: @escaping (Data?, Error?) -> Void)

    /// Returns the cached fan ceilings (F0Mn/F0Mx/F1Mn/F1Mx) read at helper boot.
    /// JSON-encoded `FanCeilings` inside Data.
    func getFanCeilings(reply: @escaping (Data?, Error?) -> Void)

    /// Reverts SMC to Auto, stops the control loop, removes control.json. Daemon stays installed.
    func uninstall(reply: @escaping (Bool, Error?) -> Void)
}

/// Mach service name used by both endpoints to bind/connect.
public enum HelperConstants {
    public static let machServiceName = "com.breezefan.helper"
    public static let helperBundleID = "com.breezefan.helper"
    public static let appBundleID = "com.breezefan.app"
}
