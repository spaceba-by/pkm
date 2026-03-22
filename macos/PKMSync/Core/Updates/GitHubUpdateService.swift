import Foundation

protocol UpdateServiceProtocol: Sendable {
    func checkForUpdate(currentVersion: String) async throws -> AppUpdate?
    func downloadUpdate(_ update: AppUpdate, progress: @Sendable (Double) -> Void) async throws -> URL
}

final class GitHubUpdateService: UpdateServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let repoOwner: String
    private let repoName: String
    private let tagPrefix: String

    init(
        session: URLSession = .shared,
        repoOwner: String = "spaceba-by",
        repoName: String = "pkm",
        tagPrefix: String = "macos-v"
    ) {
        self.session = session
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.tagPrefix = tagPrefix
    }

    func checkForUpdate(currentVersion: String) async throws -> AppUpdate? {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UpdateError.networkError("Unexpected status code \(statusCode)")
        }

        let releases = try JSONDecoder.githubDecoder.decode([GitHubRelease].self, from: data)

        // Find the first suitable release matching our tag prefix that is newer and has a zip asset
        for release in releases where release.tagName.hasPrefix(tagPrefix) && !release.draft && !release.prerelease {
            let remoteVersion = release.tagName

            guard VersionComparator.isNewer(remoteVersion, than: currentVersion) else {
                continue
            }

            guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
                continue
            }

            return AppUpdate(
                version: SemanticVersion(string: remoteVersion)?.description ?? remoteVersion,
                releaseNotes: release.body ?? "",
                downloadURL: asset.browserDownloadUrl,
                publishedAt: release.publishedAt ?? Date(),
                assetSize: asset.size
            )
        }

        return nil
    }

    func downloadUpdate(_ update: AppUpdate, progress: @Sendable (Double) -> Void) async throws -> URL {
        let (tempURL, response) = try await session.download(from: update.downloadURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw UpdateError.networkError("Download failed")
        }

        // Move to a stable temp location (URLSession temp files get cleaned up)
        let destDir = FileManager.default.temporaryDirectory.appendingPathComponent("pkmsync-update")
        try? FileManager.default.removeItem(at: destDir)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        progress(1.0)
        return destURL
    }
}

// MARK: - GitHub API Models

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [GitHubAsset]
}

private struct GitHubAsset: Decodable {
    let name: String
    let size: Int64
    let browserDownloadUrl: URL
}

private extension JSONDecoder {
    static let githubDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            // Retry without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case networkError(String)
    case appNotFoundInArchive
    case installFailed(String)
    case noWriteAccess

    var errorDescription: String? {
        switch self {
        case let .networkError(message): "Network error: \(message)"
        case .appNotFoundInArchive: "Could not find .app bundle in downloaded archive"
        case let .installFailed(message): "Install failed: \(message)"
        case .noWriteAccess: "No write access to application location. Try moving the app to a writable location."
        }
    }
}
