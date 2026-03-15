import Foundation

struct ConflictFile: Identifiable, Sendable, Equatable {
    let id: UUID
    let originalPath: String
    let conflictPath: String
    let originalModified: Date?
    let conflictModified: Date?

    init(
        id: UUID = UUID(),
        originalPath: String,
        conflictPath: String,
        originalModified: Date? = nil,
        conflictModified: Date? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.conflictPath = conflictPath
        self.originalModified = originalModified
        self.conflictModified = conflictModified
    }

    var originalFileName: String {
        (originalPath as NSString).lastPathComponent
    }

    func relativePath(from vaultPath: String) -> String {
        if originalPath.hasPrefix(vaultPath) {
            let trimmed = String(originalPath.dropFirst(vaultPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return trimmed.isEmpty ? originalFileName : trimmed
        }
        return originalFileName
    }
}

enum ConflictResolution: Sendable {
    case keepOriginal
    case keepConflict
}
