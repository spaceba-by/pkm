import Foundation

struct SyncLogEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let filesTransferred: Int
    let filesChecked: Int
    let success: Bool
    let errorMessage: String?
    let rawOutput: String?
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        filesTransferred: Int = 0,
        filesChecked: Int = 0,
        success: Bool = true,
        errorMessage: String? = nil,
        rawOutput: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.filesTransferred = filesTransferred
        self.filesChecked = filesChecked
        self.success = success
        self.errorMessage = errorMessage
        self.rawOutput = rawOutput
        self.duration = duration
    }
}
