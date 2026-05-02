import Foundation
import ServiceManagement

/// Singleton XPC client for the App-side. Manages NSXPCConnection lifecycle, exposes
/// async methods that mirror `HelperProtocol`.
@MainActor
final class HelperClient {
    static let shared = HelperClient()

    private var connection: NSXPCConnection?

    private init() {}

    // MARK: - Connection management

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }

        let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection?.invalidate()
                self?.connection = nil
            }
        }
        conn.resume()
        self.connection = conn
        return conn
    }

    private func proxy() -> HelperProtocol {
        let conn = ensureConnection()
        return conn.remoteObjectProxyWithErrorHandler { _ in
            // Errors are reported per-call via reply blocks.
        } as! HelperProtocol
    }

    // MARK: - Public API

    func ping() async throws -> Date {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Date, Error>) in
            proxy().ping { date in
                cont.resume(returning: date)
            }
        }
    }

    func getSnapshot() async throws -> SensorSnapshot {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SensorSnapshot, Error>) in
            proxy().getSnapshot { data, error in
                if let error {
                    cont.resume(throwing: error); return
                }
                guard let data else {
                    cont.resume(throwing: HelperError.invalidPayload); return
                }
                do {
                    let snap = try JSONDecoder().decode(SensorSnapshot.self, from: data)
                    cont.resume(returning: snap)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func setMode(_ mode: ControlMode) async throws {
        let data = try JSONEncoder().encode(mode)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy().setMode(data) { ok, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: ok ? () : ())
            }
        }
    }

    func setCurve(_ curve: Curve) async throws {
        let data = try JSONEncoder().encode(curve)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy().setCurve(data) { ok, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: ok ? () : ())
            }
        }
    }

    func applyPreset(_ preset: Preset) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy().applyPreset(preset.rawValue) { ok, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: ok ? () : ())
            }
        }
    }

    func getModelInfo() async throws -> (model: String, readOnly: Bool) {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Bool), Error>) in
            proxy().getModelInfo { model, readOnly in
                cont.resume(returning: (model, readOnly))
            }
        }
    }

    func uninstall() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy().uninstall { ok, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: ok ? () : ())
            }
        }
    }

    // MARK: - Helper installation

    enum InstallResult {
        case alreadyEnabled
        case requiresApproval
        case approved
        case failed(Error)
    }

    /// Registers the helper via SMAppService.daemon. Triggers admin password prompt the first time.
    func installHelperIfNeeded() -> InstallResult {
        let service = SMAppService.daemon(plistName: "com.fancontrol.helper.plist")

        switch service.status {
        case .enabled:
            return .alreadyEnabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound, .notRegistered:
            do {
                try service.register()
                return .approved
            } catch {
                return .failed(error)
            }
        @unknown default:
            do {
                try service.register()
                return .approved
            } catch {
                return .failed(error)
            }
        }
    }

    func uninstallHelper() async throws {
        let service = SMAppService.daemon(plistName: "com.fancontrol.helper.plist")
        try await service.unregister()
    }
}
