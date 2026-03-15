import Foundation

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case error(String)

    var iconName: String {
        switch self {
        case .idle:
            "arrow.triangle.2.circlepath"
        case .syncing:
            "arrow.triangle.2.circlepath"
        case .error:
            "exclamationmark.triangle"
        }
    }

    var label: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing..."
        case let .error(message):
            "Error: \(message)"
        }
    }
}
