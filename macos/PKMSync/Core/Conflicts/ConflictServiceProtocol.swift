import Foundation

protocol ConflictServiceProtocol: Sendable {
    func scanForConflicts(in vaultPath: String) async throws -> [ConflictFile]
    func resolveConflict(_ conflict: ConflictFile, resolution: ConflictResolution) throws
}
