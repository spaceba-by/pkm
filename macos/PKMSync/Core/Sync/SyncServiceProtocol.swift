import Foundation

protocol SyncServiceProtocol: Sendable {
    func sync() async throws -> SyncLogEntry
    func resync() async throws -> SyncLogEntry
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
