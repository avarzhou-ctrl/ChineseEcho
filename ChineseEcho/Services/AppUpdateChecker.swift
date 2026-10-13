import Foundation
import Observation

// Describes a newer published release the learner can download.
nonisolated struct AvailableAppUpdate: Equatable, Sendable {
    let version: String
    let downloadURL: URL
    let releaseNotesURL: URL
}

// Compares dot-separated numeric versions so "1.10" correctly sorts after "1.9".
nonisolated enum AppVersion {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = components(candidate)
        let rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespaces).trimmingPrefix(while: { $0 == "v" || $0 == "V" }).description
    }

    private static func components(_ version: String) -> [Int] {
        normalized(version).split(separator: ".").map { Int($0) ?? 0 }
    }
}

// Checks GitHub Releases for a newer version; there is no ChineseEcho server, so this is the only update source.
@MainActor
@Observable
final class AppUpdateChecker {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(AvailableAppUpdate)
        case failed(String)
    }

    static let shared = AppUpdateChecker()

    static let releasesPageURL = URL(string: "https://github.com/avarzhou-ctrl/ChineseEcho/releases/latest")!
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/avarzhou-ctrl/ChineseEcho/releases/latest"
    )!
    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private(set) var phase: Phase = .idle
    private(set) var lastCheckedAt: Date?

    let currentVersion: String

    private let defaults: UserDefaults
    private let session: URLSession

    init(defaults: UserDefaults = .standard, session: URLSession = .shared, bundle: Bundle = .main) {
        self.defaults = defaults
        self.session = session
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        lastCheckedAt = defaults.object(forKey: AppPreferenceKey.lastUpdateCheck) as? Date
        if let cachedVersion = defaults.string(forKey: AppPreferenceKey.latestKnownVersion),
           AppVersion.isNewer(cachedVersion, than: currentVersion),
           let update = Self.update(forVersion: cachedVersion) {
            // Keep a previously found update visible across launches without another request.
            phase = .available(update)
        }
    }

    var availableUpdate: AvailableAppUpdate? {
        if case .available(let update) = phase { return update }
        return nil
    }

    // The launch card stays hidden once the learner dismisses that specific version; Settings still lists it.
    var shouldShowUpdateCard: Bool {
        guard let availableUpdate else { return false }
        return defaults.string(forKey: AppPreferenceKey.dismissedUpdateVersion) != availableUpdate.version
    }

    func dismissUpdateCard() {
        guard let availableUpdate else { return }
        defaults.set(availableUpdate.version, forKey: AppPreferenceKey.dismissedUpdateVersion)
        // Reassigning the phase notifies observers because the dismissal lives in UserDefaults.
        phase = .available(availableUpdate)
    }

    func checkIfDue() async {
        let isEnabled = defaults.object(forKey: AppPreferenceKey.automaticUpdateChecks) as? Bool
            ?? AppPreferenceDefault.automaticUpdateChecks
        guard isEnabled else { return }
        if let lastCheckedAt, Date.now.timeIntervalSince(lastCheckedAt) < Self.automaticCheckInterval {
            return
        }
        await checkNow(reportsFailures: false)
    }

    func checkNow(reportsFailures: Bool = true) async {
        guard phase != .checking else { return }
        let previousPhase = phase
        phase = .checking

        do {
            let latestVersion = try await fetchLatestVersion()
            lastCheckedAt = .now
            defaults.set(lastCheckedAt, forKey: AppPreferenceKey.lastUpdateCheck)
            defaults.set(latestVersion, forKey: AppPreferenceKey.latestKnownVersion)

            if AppVersion.isNewer(latestVersion, than: currentVersion),
               let update = Self.update(forVersion: latestVersion) {
                phase = .available(update)
            } else {
                phase = .upToDate
            }
        } catch {
            // Background checks fail quietly so offline learners never see network noise.
            phase = reportsFailures
                ? .failed("Couldn’t reach GitHub. Check your internet connection and try again.")
                : previousPhase
        }
    }

    private func fetchLatestVersion() async throws -> String {
        var request = URLRequest(url: Self.latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ChineseEcho/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return AppVersion.normalized(release.tagName)
    }

    // Release assets use a stable unversioned name, so the newest ZIP always lives at one URL.
    private static func update(forVersion version: String) -> AvailableAppUpdate? {
        guard let releaseNotesURL = URL(
            string: "https://github.com/avarzhou-ctrl/ChineseEcho/releases/tag/v\(version)"
        ) else { return nil }
        return AvailableAppUpdate(
            version: version,
            downloadURL: URL(
                string: "https://github.com/avarzhou-ctrl/ChineseEcho/releases/latest/download/ChineseEcho-macOS.zip"
            )!,
            releaseNotesURL: releaseNotesURL
        )
    }
}

// Decodes only the release field the version comparison needs.
private nonisolated struct GitHubRelease: Decodable, Sendable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
