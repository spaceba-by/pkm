import Foundation

struct ConflictService: ConflictServiceProtocol {
    func scanForConflicts(in vaultPath: String) async throws -> [ConflictFile] {
        let vaultURL = URL(fileURLWithPath: vaultPath)
        guard FileManager.default.fileExists(atPath: vaultPath) else {
            return []
        }

        var conflicts: [ConflictFile] = []

        let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let path = fileURL.path
            guard path.contains(".conflict") else { continue }

            let originalPath = deriveOriginalPath(from: path)
            let conflictModified = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            let originalModified = try? URL(fileURLWithPath: originalPath).resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate

            conflicts.append(ConflictFile(
                originalPath: originalPath,
                conflictPath: path,
                originalModified: originalModified,
                conflictModified: conflictModified
            ))
        }

        return conflicts
    }

    func resolveConflict(_ conflict: ConflictFile, resolution: ConflictResolution) throws {
        switch resolution {
        case .keepOriginal:
            try FileManager.default.removeItem(atPath: conflict.conflictPath)
        case .keepConflict:
            if FileManager.default.fileExists(atPath: conflict.originalPath) {
                try FileManager.default.removeItem(atPath: conflict.originalPath)
            }
            try FileManager.default.moveItem(
                atPath: conflict.conflictPath,
                toPath: conflict.originalPath
            )
        }
    }

    private func deriveOriginalPath(from conflictPath: String) -> String {
        // rclone conflict files are named like: file.conflict1.md or file.md.conflict1
        // Try to strip the .conflictN part
        let pattern = #"\.conflict\d*"#
        if let range = conflictPath.range(of: pattern, options: .regularExpression) {
            return conflictPath.replacingCharacters(in: range, with: "")
        }
        return conflictPath
    }
}
