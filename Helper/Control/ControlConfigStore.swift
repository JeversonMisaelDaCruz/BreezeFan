import Foundation

/// Reads / writes `/Library/Application Support/FanControl/control.json`.
public final class ControlConfigStore {
    public static let path = "/Library/Application Support/FanControl/control.json"
    private let fm = FileManager.default
    private let url: URL

    public init(path: String = ControlConfigStore.path) {
        self.url = URL(fileURLWithPath: path)
    }

    /// Loads existing config or returns defaults.
    public func load() -> ControlConfig {
        guard fm.fileExists(atPath: url.path) else { return .defaults }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ControlConfig.self, from: data)
        } catch {
            HelperLogger.control.warn("Failed to load control.json: \(error.localizedDescription) — using defaults")
            return .defaults
        }
    }

    public func save(_ cfg: ControlConfig) throws {
        try ensureDirectory()
        var snapshot = cfg
        snapshot.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    public func remove() {
        try? fm.removeItem(at: url)
    }

    private func ensureDirectory() throws {
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
