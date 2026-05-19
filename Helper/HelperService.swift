import Foundation

/// Concrete XPC server. Implements `HelperProtocol`.
/// Singleton because it manages stateful subsystems (ControlLoop, ConfigStore, etc.).
final class HelperService: NSObject, HelperProtocol, @unchecked Sendable {
    static let shared = HelperService()

    private let queue = DispatchQueue(label: "com.breezefan.helper.service", qos: .userInitiated)

    /// Shared JSON coders — reuse instead of allocating per XPC reply.
    /// Confined to `queue` so we never touch them from two threads at once.
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var sensorPoller: SensorPolling?
    private var modeManager: ModeManaging?
    private var ceilingsProvider: CeilingsProviding?
    private var readOnly: Bool = false
    private var modelIdentifier: String = ""

    func wire(
        sensorPoller: SensorPolling,
        modeManager: ModeManaging,
        ceilingsProvider: CeilingsProviding
    ) {
        queue.async {
            self.sensorPoller = sensorPoller
            self.modeManager = modeManager
            self.ceilingsProvider = ceilingsProvider
        }
    }

    func setReadOnly(_ readOnly: Bool, model: String) {
        queue.async {
            self.readOnly = readOnly
            self.modelIdentifier = model
        }
    }

    // MARK: - HelperProtocol

    func ping(reply: @escaping (Date) -> Void) {
        let now = Date()
        HelperLogger.xpc.log("ping at \(now.timeIntervalSince1970)")
        reply(now)
    }

    func getSnapshot(reply: @escaping (Data?, Error?) -> Void) {
        queue.async {
            guard let poller = self.sensorPoller else {
                let snapshot = SensorSnapshot.empty
                self.encodeAndReply(snapshot, reply: reply)
                return
            }
            let snapshot = poller.latestSnapshot()
            self.encodeAndReply(snapshot, reply: reply)
        }
    }

    func setMode(_ modeData: Data, reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            if self.readOnly {
                reply(false, HelperError.unsupportedModel(self.modelIdentifier))
                return
            }
            guard let mode = try? self.decoder.decode(ControlMode.self, from: modeData) else {
                reply(false, HelperError.invalidPayload)
                return
            }
            guard let manager = self.modeManager else {
                reply(false, HelperError.notInstalled)
                return
            }
            do {
                try manager.setMode(mode)
                reply(true, nil)
            } catch {
                reply(false, error)
            }
        }
    }

    func setCurve(_ curveData: Data, reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            if self.readOnly {
                reply(false, HelperError.unsupportedModel(self.modelIdentifier))
                return
            }
            guard let curve = try? self.decoder.decode(Curve.self, from: curveData) else {
                reply(false, HelperError.invalidPayload)
                return
            }
            if case .failure(let err) = CurveValidator.validate(curve) {
                reply(false, HelperError.invalidCurve(reason: "\(err)"))
                return
            }
            guard let manager = self.modeManager else {
                reply(false, HelperError.notInstalled)
                return
            }
            do {
                try manager.setCurve(curve)
                reply(true, nil)
            } catch {
                reply(false, error)
            }
        }
    }

    func applyPreset(_ presetRawValue: String, reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            if self.readOnly {
                reply(false, HelperError.unsupportedModel(self.modelIdentifier))
                return
            }
            guard let preset = Preset(rawValue: presetRawValue) else {
                reply(false, HelperError.invalidPayload)
                return
            }
            guard let manager = self.modeManager else {
                reply(false, HelperError.notInstalled)
                return
            }
            do {
                try manager.applyPreset(preset)
                reply(true, nil)
            } catch {
                reply(false, error)
            }
        }
    }

    func getModelInfo(reply: @escaping (String, Bool) -> Void) {
        queue.async {
            let model = self.modelIdentifier.isEmpty ? ModelDetector.current : self.modelIdentifier
            let isReadOnly = self.readOnly || !ModelDetector.isSupported(model: model)
            reply(model, isReadOnly)
        }
    }

    func getFanCeilings(reply: @escaping (Data?, Error?) -> Void) {
        queue.async {
            let ceilings = self.ceilingsProvider?.ceilings ?? FanCeilings.defaults
            do {
                let data = try self.encoder.encode(ceilings)
                reply(data, nil)
            } catch {
                reply(nil, error)
            }
        }
    }

    func uninstall(reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            guard let manager = self.modeManager else {
                reply(true, nil) // Nothing to undo
                return
            }
            do {
                try manager.uninstall()
                reply(true, nil)
            } catch {
                reply(false, error)
            }
        }
    }

    // MARK: - Helpers

    private func encodeAndReply(_ snapshot: SensorSnapshot, reply: (Data?, Error?) -> Void) {
        do {
            let data = try self.encoder.encode(snapshot)
            reply(data, nil)
        } catch {
            reply(nil, error)
        }
    }
}

/// Subsystem protocols — concrete impls land in later phases.
protocol SensorPolling: AnyObject {
    func latestSnapshot() -> SensorSnapshot
}

protocol ModeManaging: AnyObject {
    func setMode(_ mode: ControlMode) throws
    func setCurve(_ curve: Curve) throws
    func applyPreset(_ preset: Preset) throws
    func uninstall() throws
}

protocol CeilingsProviding: AnyObject {
    var ceilings: FanCeilings { get }
}

extension SnapshotBuilder: CeilingsProviding {}
