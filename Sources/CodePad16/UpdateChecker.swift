import AppKit
import Combine
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate(current: String, latest: String)
        case downloading(version: String)
        case downloaded(version: String, file: URL)
        case installing(version: String)
        case failed(String)
    }

    static let releasesAPI = URL(string: "https://api.github.com/repos/mpschahal16/codepad16-macos/releases?per_page=20")!
    static let releasesPageURL = URL(string: "https://github.com/mpschahal16/codepad16-macos/releases")!

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var releasePageURL = UpdateChecker.releasesPageURL
    @Published var isPresented = false

    private let versionOverride: String?
    private let downloadsDirectory: URL?
    private var isChecking = false

    init(currentVersion: String? = nil, downloadsDirectory: URL? = nil) {
        self.versionOverride = currentVersion
        self.downloadsDirectory = downloadsDirectory
    }

    var currentVersion: String {
        if let versionOverride { return versionOverride }
        let info = Bundle.main.infoDictionary
        return info?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    func checkForUpdates() {
        isPresented = true
        guard !isChecking else { return }
        isChecking = true
        phase = .checking
        Task {
            await check()
            isChecking = false
        }
    }

    func installDownloadedUpdate() {
        guard case .downloaded(let version, let file) = phase else { return }
        phase = .installing(version: version)
        UpdateInstaller.install(dmg: file) { [weak self] result in
            Task { @MainActor in
                guard let self, case .failure(let error) = result else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    private func check() async {
        do {
            let releases = try await fetchReleases()
            // `max(by:)` takes an "is ordered before" predicate, so compare
            // each older tag against the next newer one.
            guard let latest = releases.filter({ !$0.draft }).max(by: {
                Self.isNewer($1.tagName, than: $0.tagName)
            }) else {
                throw UpdateError.noReleases
            }

            releasePageURL = latest.htmlURL
            let latestVersion = Self.displayVersion(latest.tagName)

            guard Self.isNewer(latest.tagName, than: currentVersion) else {
                phase = .upToDate(current: currentVersion, latest: latestVersion)
                return
            }

            guard let asset = latest.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
                throw UpdateError.noAsset
            }

            phase = .downloading(version: latestVersion)
            let file = try await download(asset)
            phase = .downloaded(version: latestVersion, file: file)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func fetchReleases() async throws -> [Release] {
        var request = URLRequest(url: Self.releasesAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CodePad16/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw UpdateError.badResponse
        }
        return try JSONDecoder().decode([Release].self, from: data)
    }

    private func download(_ asset: Release.Asset) async throws -> URL {
        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("CodePad16/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw UpdateError.badResponse
        }

        let directory = downloadsDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = Self.availableURL(in: directory, name: asset.name)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    // MARK: - Version parsing

    static func displayVersion(_ tag: String) -> String {
        let components = versionComponents(tag)
        return components.isEmpty ? tag : components.map(String.init).joined(separator: ".")
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = versionComponents(candidate)
        guard !candidateParts.isEmpty else { return false }
        let currentParts = versionComponents(current)
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < currentParts.count ? currentParts[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private static func versionComponents(_ text: String) -> [Int] {
        guard let range = text.range(of: #"[0-9]+(?:\.[0-9]+)+"#, options: .regularExpression) else {
            return []
        }
        return text[range].split(separator: ".").compactMap { Int($0) }
    }

    private static func availableURL(in directory: URL, name: String) -> URL {
        let first = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: first.path) else { return first }
        let base = first.deletingPathExtension().lastPathComponent
        let ext = first.pathExtension
        var index = 2
        while true {
            let candidate = directory.appendingPathComponent("\(base) \(index).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    // MARK: - GitHub models

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case assets
        }
    }

    private enum UpdateError: LocalizedError {
        case noReleases
        case noAsset
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noReleases:
                return "No published releases were found."
            case .noAsset:
                return "The latest release has no disk image to download."
            case .badResponse:
                return "GitHub returned an unexpected response."
            }
        }
    }
}
