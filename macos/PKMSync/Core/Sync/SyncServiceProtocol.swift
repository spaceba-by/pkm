import Foundation

protocol SyncServiceProtocol: Sendable {
    /// - Parameter onProgress: Called with a snapshot each time rclone reports
    ///   forward motion. Delivered serially on an arbitrary thread.
    func sync(onProgress: (@Sendable (SyncProgress) -> Void)?) async throws -> SyncLogEntry
    func resync(onProgress: (@Sendable (SyncProgress) -> Void)?) async throws -> SyncLogEntry
}

extension SyncServiceProtocol {
    func sync() async throws -> SyncLogEntry {
        try await sync(onProgress: nil)
    }

    func resync() async throws -> SyncLogEntry {
        try await resync(onProgress: nil)
    }
}

enum SyncError: Error, LocalizedError, Sendable {
    case rcloneNotFound
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .rcloneNotFound:
            "rclone binary not found"
        case .notConfigured:
            "Sync is not configured. Set vault path and bucket name in Settings."
        }
    }
}
