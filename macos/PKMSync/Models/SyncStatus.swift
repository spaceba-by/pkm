import Foundation

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing(SyncProgress)
    case error(String)

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }

    /// The live progress snapshot, or `nil` when no sync is running.
    var progress: SyncProgress? {
        if case let .syncing(progress) = self { return progress }
        return nil
    }

    var iconName: String {
        switch self {
        case .idle:
            "arrow.triangle.2.circlepath"
        case .syncing:
            "arrow.triangle.2.circlepath.circle"
        case .error:
            "exclamationmark.triangle"
        }
    }

    var label: String {
        switch self {
        case .idle:
            "Idle"
        case let .syncing(progress):
            progress.phase.label
        case let .error(message):
            "Error: \(message)"
        }
    }
}
