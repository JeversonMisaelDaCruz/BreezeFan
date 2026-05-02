import Foundation

/// Persists app-side UI state to ~/Library/Application Support/FanControl/state.json.
public struct PersistedAppState: Codable, Equatable {
    public var version: Int
    public var accentHex: String
    public var tempUnit: String
    public var activeCurve: Curve
    public var activePresetRaw: String?
    public var menuBarOnly: Bool

    public init(
        version: Int = 1,
        accentHex: String = "#3b82f6",
        tempUnit: String = "C",
        activeCurve: Curve = .default,
        activePresetRaw: String? = nil,
        menuBarOnly: Bool = false
    ) {
        self.version = version
        self.accentHex = accentHex
        self.tempUnit = tempUnit
        self.activeCurve = activeCurve
        self.activePresetRaw = activePresetRaw
        self.menuBarOnly = menuBarOnly
    }

    public static let defaults = PersistedAppState()

    /// Allow decoding older state.json files that lack `menuBarOnly`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex) ?? "#3b82f6"
        self.tempUnit = try c.decodeIfPresent(String.self, forKey: .tempUnit) ?? "C"
        self.activeCurve = try c.decodeIfPresent(Curve.self, forKey: .activeCurve) ?? .default
        self.activePresetRaw = try c.decodeIfPresent(String.self, forKey: .activePresetRaw)
        self.menuBarOnly = try c.decodeIfPresent(Bool.self, forKey: .menuBarOnly) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case version, accentHex, tempUnit, activeCurve, activePresetRaw, menuBarOnly
    }
}

public final class StateStore {
    public static var defaultPath: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("FanControl", isDirectory: true)
        return dir.appendingPathComponent("state.json")
    }

    private let url: URL
    private let fm = FileManager.default

    public init(url: URL = StateStore.defaultPath) {
        self.url = url
    }

    public func load() -> PersistedAppState {
        guard fm.fileExists(atPath: url.path) else { return .defaults }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PersistedAppState.self, from: data)
        } catch {
            return .defaults
        }
    }

    public func save(_ state: PersistedAppState) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: [.atomic])
    }

    private func ensureDirectory() throws {
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
