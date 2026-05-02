import Foundation

/// Entry point of the FanControlHelper LaunchDaemon.
@main
enum HelperMain {
    static func main() {
        HelperLogger.xpc.log("FanControlHelper boot — bundle=\(HelperConstants.helperBundleID)")

        // Detect hardware. On unsupported models we accept connections but reject mutations.
        let model = ModelDetector.current
        let supported = ModelDetector.isSupported(model: model)
        if !supported {
            HelperLogger.control.warn("Unsupported model \(model), entering read-only mode")
        } else {
            HelperLogger.control.log("Hardware: \(model) — full control mode")
        }

        // Wire SMC + sensors.
        do {
            let smcReader = try SMCReaderImpl()
            let smcWriter = try SMCWriterImpl()
            let ioHID = IOHIDReader()
            let tempReader = TemperatureReader(smc: smcReader, ioHID: ioHID)
            let snapshotBuilder = SnapshotBuilder(smc: smcReader, temp: tempReader)
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
                configProvider: { store.load() }
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
            HelperService.shared.setReadOnly(!supported, model: model)

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
