import Foundation

/// Reads / writes `/Library/Application Support/BreezeFan/control.json`.
///
/// Performance notes:
/// - In-memory cache backs `current`. The control loop reads config every tick — without
///   the cache that meant a `fileExists` + `Data(contentsOf:)` + JSON decode every 1.5s.
/// - JSONEncoder/JSONDecoder are instance properties (configured once with the iso8601
///   date strategy), not allocated per save/load.
public final class ControlConfigStore: @unchecked Sendable {
    public static let path = "/Library/Application Support/BreezeFan/control.json"
    private let fm = FileManager.default
    private let url: URL

    private let cacheLock = NSLock()
    private var cached: ControlConfig?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(path: String = ControlConfigStore.path) {
        self.url = URL(fileURLWithPath: path)
    }

    /// Returns the cached config, loading from disk on first access. Thread-safe.
    /// Use this on hot paths (e.g. the per-tick control loop) instead of `load()`.
    public var current: ControlConfig {
        cacheLock.lock()
        if let c = cached {
            cacheLock.unlock()
            return c
        }
        cacheLock.unlock()
        return load()
    }

    /// Loads existing config from disk or returns defaults. Updates the in-memory cache.
    @discardableResult
    public func load() -> ControlConfig {
        let result: ControlConfig
        if fm.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                result = try decoder.decode(ControlConfig.self, from: data)
            } catch {
                HelperLogger.control.warn("Failed to load control.json: \(error.localizedDescription) — using defaults")
                result = .defaults
            }
        } else {
            result = .defaults
        }
        cacheLock.lock()
        cached = result
        cacheLock.unlock()
        return result
    }

    public func save(_ cfg: ControlConfig) throws {
        try ensureDirectory()
        var snapshot = cfg
        snapshot.updatedAt = Date()
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
        cacheLock.lock()
        cached = snapshot
        cacheLock.unlock()
    }

    public func remove() {
        try? fm.removeItem(at: url)
        cacheLock.lock()
        cached = nil
        cacheLock.unlock()
    }

    private func ensureDirectory() throws {
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
