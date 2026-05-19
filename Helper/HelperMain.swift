import Foundation

/// Entry point of the BreezeFanHelper LaunchDaemon.
@main
enum HelperMain {
    static func main() {
        HelperLogger.xpc.log("BreezeFanHelper boot — bundle=\(HelperConstants.helperBundleID)")

        // Detect hardware. Resolve the model profile up front so every subsystem
        // uses the right temp keys / fan count / control policy.
        let profile = ModelDetector.currentProfile
        let supported = profile.controlSupported
        if !supported {
            HelperLogger.control.warn(
                "Read-only mode — model=\(profile.identifier) fanCount=\(profile.fanCount) " +
                "(profile.controlSupported=false)"
            )
        } else {
            HelperLogger.control.log(
                "Hardware: \(profile.displayName) (\(profile.identifier)) " +
                "fanCount=\(profile.fanCount) — full control mode"
            )
        }

        // Wire SMC + sensors.
        do {
            let smcReader = try SMCReaderImpl()
            let smcWriter = try SMCWriterImpl()
            let ioHID = IOHIDReader()
            let tempReader = TemperatureReader(
                smc: smcReader,
                ioHID: ioHID,
                tempKeys: profile.tempKeys
            )
            let snapshotBuilder = SnapshotBuilder(
                smc: smcReader,
                temp: tempReader,
                fanCount: profile.fanCount
            )
            let poller = SensorPoller(builder: snapshotBuilder)
            let pollAdapter = SensorPollingAdapter(poller: poller)
            pollAdapter.startPump()

            // Control subsystems.
            let store = ControlConfigStore()
            let cfg = store.load()
            let controlLoop = ControlLoop(
                smcReader: smcReader,
                smcWriter: smcWriter,
                f0Mn: snapshotBuilder.f0Mn,
                f0Mx: snapshotBuilder.f0Mx,
                f1Mn: snapshotBuilder.f1Mn,
                f1Mx: snapshotBuilder.f1Mx,
                snapshotProvider: { pollAdapter.latestSnapshot() },
                configProvider: { store.current }
            )
            let modeManager = ModeManager(
                store: store,
                smcWriter: smcWriter,
                controlLoop: controlLoop,
                f0Mn: snapshotBuilder.f0Mn,
                f0Mx: snapshotBuilder.f0Mx,
                f1Mn: snapshotBuilder.f1Mn,
                f1Mx: snapshotBuilder.f1Mx
            )

            // Boot in restored mode (if anything other than auto, start the loop).
            if cfg.modeKind != .auto {
                controlLoop.start()
            }

            // Watchdog.
            let watchdog = Watchdog(smcWriter: smcWriter, controlLoop: controlLoop)
            watchdog.start()

            // Wire to XPC service.
            HelperService.shared.wire(
                sensorPoller: pollAdapter,
                modeManager: modeManager,
                ceilingsProvider: snapshotBuilder
            )
            HelperService.shared.setReadOnly(!supported, model: profile.identifier)
            // Publish capabilities snapshot. `temperatureSourceValid` is best-effort:
            // for known profiles we trust the SMC key list; the first snapshot
            // poll will refine if every read returns nil.
            HelperService.shared.setCapabilities(
                profile.capabilities(temperatureSourceValid: !profile.tempKeys.isEmpty)
            )

            HelperLogger.control.log("Helper subsystems initialized — mode=\(cfg.modeKind.rawValue)")
        } catch {
            HelperLogger.smc.warn("SMC initialization failed: \(error.localizedDescription) — running in degraded mode")
            // Helper still serves XPC ping/getModelInfo, but mutations will fail.
        }

        // Boot XPC listener.
        let delegate = HelperListenerDelegate()
        let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        listener.delegate = delegate
        listener.resume()
        HelperLogger.xpc.log("Listener resumed on \(HelperConstants.machServiceName)")

        RunLoop.main.run()
    }
}

/// NSXPCListener delegate. Validates incoming connections, then wires up HelperService.
final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let validator: XPCConnectionValidator

    init(validator: XPCConnectionValidator = XPCConnectionValidator()) {
        self.validator = validator
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        switch validator.validate(connection: newConnection) {
        case .valid:
            break
        case .invalid(let reason):
            HelperLogger.xpc.warn("Rejected XPC connection from pid=\(newConnection.processIdentifier): \(reason)")
            return false
        }

        let exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedInterface = exportedInterface
        newConnection.exportedObject = HelperService.shared

        newConnection.invalidationHandler = {
            HelperLogger.xpc.log("XPC connection invalidated.")
        }
        newConnection.interruptionHandler = {
            HelperLogger.xpc.log("XPC connection interrupted.")
        }

        newConnection.resume()
        HelperLogger.xpc.log("Accepted XPC connection from pid=\(newConnection.processIdentifier)")
        return true
    }
}
