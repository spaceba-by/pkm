import Foundation

protocol SyncServiceProtocol: Sendable {
    func sync() async throws -> SyncLogEntry
    func resync() async throws -> SyncLogEntry
}

enum SyncError: Error, LocalizedError, Sendable {
    case rcloneNotFound
    case notConfigured
    case processError(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .rcloneNotFound:
            "rclone binary not found"
        case .notConfigured:
            "Sync is not configured. Set vault path and bucket name in Settings."
        case let .processError(exitCode, stderr):
            "rclone exited with code \(exitCode): \(stderr.prefix(200))"
        }
    }
}
