import Foundation
import os.log

/// Checks the GitHub Releases API for a newer version of the app and exposes
/// the result via AppState.availableUpdate.
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// GitHub repo to query. Adjust if forked/renamed.
    private let owner = "JeversonMisaelDaCruz"
    private let repo = "Macfancontrol"

    private var lastCheck: Date = .distantPast

    private init() {}

    /// Returns true if the version on GitHub is newer than the running version.
    /// Updates `AppState.shared.availableUpdate` with the release info on success.
    @discardableResult
    func checkForUpdates(force: Bool = false) async -> ReleaseInfo? {
        // Throttle: only re-check every 6 hours unless forced.
        let now = Date()
        if !force && now.timeIntervalSince(lastCheck) < 6 * 3600 {
            return AppState.shared.availableUpdate
        }
        lastCheck = now

        guard let release = await fetchLatestRelease() else { return nil }

        let current = AppVersion.current
        let remote = AppVersion.parse(release.tagName)

        AppLogger.main.info(
            "\("update check: current=\(current) remote=\(remote ?? .zero) tag=\(release.tagName)", privacy: .public)"
        )

        if let remote, remote > current {
            AppState.shared.availableUpdate = release
            return release
        } else {
            AppState.shared.availableUpdate = nil
            return nil
        }
    }

    /// Hits the GitHub Releases API. Returns nil on any error.
    private func fetchLatestRelease() async -> ReleaseInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FanControl-update-checker", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
            return release
        } catch {
            AppLogger.main.info("\("update check failed: \(error)", privacy: .public)")
            return nil
        }
    }
}

/// Subset of GitHub Releases API JSON response we care about.
struct ReleaseInfo: Codable, Equatable {
    let tagName: String
    let name: String?
    let htmlUrl: String
    let body: String?
    let publishedAt: String?

    var displayVersion: String {
        AppVersion.parse(tagName).map(\.string) ?? tagName
    }

    var releaseURL: URL? {
        URL(string: htmlUrl)
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
    }
}

/// Semantic version triple. Compare two versions to decide if remote is newer.
struct AppVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    static let zero = AppVersion(major: 0, minor: 0, patch: 0)

    /// The current running version, read from CFBundleShortVersionString in Info.plist.
    static var current: AppVersion {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return parse(raw) ?? .zero
    }

    /// Parses "v0.2.0", "0.2.0", "0.2", "0" — returns nil for unparseable input.
    static func parse(_ raw: String) -> AppVersion? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix("v") ? String(raw.dropFirst()) : raw
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        let major = parts.count > 0 ? parts[0] : 0
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0
        return AppVersion(major: major, minor: minor, patch: patch)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    var string: String { "\(major).\(minor).\(patch)" }
    var description: String { string }
}
