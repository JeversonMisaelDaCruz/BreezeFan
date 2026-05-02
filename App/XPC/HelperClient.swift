import Foundation
import ServiceManagement

/// Errors specific to the App-side XPC client. Surface in UI banners.
public enum HelperClientError: Error, LocalizedError {
    case helperNotRunning
    case timeout(operation: String)
    case decodingFailed
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .helperNotRunning:        return "Helper is not running. Open System Settings → Login Items to approve."
        case .timeout(let op):         return "Helper did not respond to \(op) within 2s."
        case .decodingFailed:          return "Helper returned an invalid payload."
        case .underlying(let e):       return e.localizedDescription
        }
    }
}

/// Singleton XPC client for the App-side. Manages NSXPCConnection lifecycle, exposes
/// async methods that mirror `HelperProtocol`. All calls have a 2s timeout so the UI
/// never freezes when the helper is offline.
@MainActor
final class HelperClient {
    static let shared = HelperClient()

    private var connection: NSXPCConnection?
    private let timeoutSeconds: Double = 2.0

    private init() {}

    // MARK: - Connection management

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }

        let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
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

    private func proxy(error errorHandler: @escaping (Error) -> Void = { _ in }) -> HelperProtocol {
        let conn = ensureConnection()
        return conn.remoteObjectProxyWithErrorHandler { err in
            errorHandler(err)
        } as! HelperProtocol
    }

    /// Wraps any XPC call in a 2s timeout race so the UI never freezes.
    private func withTimeout<T>(_ operation: String, _ work: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask { [timeoutSeconds] in
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw HelperClientError.timeout(operation: operation)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Public API

    func ping() async throws -> Date {
        try await withTimeout("ping") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Date, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.ping { date in
                        if !resumed { resumed = true; cont.resume(returning: date) }
                    }
                }
            }
        }
    }

    func getSnapshot() async throws -> SensorSnapshot {
        try await withTimeout("getSnapshot") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SensorSnapshot, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.getSnapshot { data, error in
                        if resumed { return }
                        if let error { resumed = true; cont.resume(throwing: error); return }
                        guard let data else {
                            resumed = true; cont.resume(throwing: HelperClientError.decodingFailed); return
                        }
                        do {
                            let snap = try JSONDecoder().decode(SensorSnapshot.self, from: data)
                            resumed = true; cont.resume(returning: snap)
                        } catch {
                            resumed = true; cont.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    func setMode(_ mode: ControlMode) async throws {
        let data = try JSONEncoder().encode(mode)
        try await withTimeout("setMode") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.setMode(data) { _, error in
                        if resumed { return }
                        resumed = true
                        if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                    }
                }
            }
        }
    }

    func setCurve(_ curve: Curve) async throws {
        let data = try JSONEncoder().encode(curve)
        try await withTimeout("setCurve") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.setCurve(data) { _, error in
                        if resumed { return }
                        resumed = true
                        if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                    }
                }
            }
        }
    }

    func applyPreset(_ preset: Preset) async throws {
        try await withTimeout("applyPreset") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.applyPreset(preset.rawValue) { _, error in
                        if resumed { return }
                        resumed = true
                        if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                    }
                }
            }
        }
    }

    func getFanCeilings() async throws -> FanCeilings {
        try await withTimeout("getFanCeilings") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<FanCeilings, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.getFanCeilings { data, error in
                        if resumed { return }
                        if let error { resumed = true; cont.resume(throwing: error); return }
                        guard let data else {
                            resumed = true; cont.resume(throwing: HelperClientError.decodingFailed); return
                        }
                        do {
                            let c = try JSONDecoder().decode(FanCeilings.self, from: data)
                            resumed = true; cont.resume(returning: c)
                        } catch {
                            resumed = true; cont.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    func getModelInfo() async throws -> (model: String, readOnly: Bool) {
        try await withTimeout("getModelInfo") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Bool), Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.getModelInfo { model, readOnly in
                        if !resumed { resumed = true; cont.resume(returning: (model, readOnly)) }
                    }
                }
            }
        }
    }

    func uninstall() async throws {
        try await withTimeout("uninstall") {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                Task { @MainActor in
                    var resumed = false
                    let p = self.proxy { err in
                        if !resumed { resumed = true; cont.resume(throwing: HelperClientError.underlying(err)) }
                    }
                    p.uninstall { _, error in
                        if resumed { return }
                        resumed = true
                        if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
                    }
                }
            }
        }
    }

    // MARK: - Helper installation

    enum InstallResult: Equatable {
        case alreadyEnabled
        case requiresApproval
        case approved
        case failed(String)
    }

    /// Registers the helper via SMAppService.daemon. Triggers admin password prompt the first time.
    func installHelperIfNeeded() -> InstallResult {
        let service = SMAppService.daemon(plistName: "com.breezefan.helper.plist")

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
                return .failed(error.localizedDescription)
            }
        @unknown default:
            do {
                try service.register()
                return .approved
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }

    func uninstallHelper() async throws {
        let service = SMAppService.daemon(plistName: "com.breezefan.helper.plist")
        try await service.unregister()
    }

    func helperStatus() -> SMAppService.Status {
        SMAppService.daemon(plistName: "com.breezefan.helper.plist").status
    }
}
