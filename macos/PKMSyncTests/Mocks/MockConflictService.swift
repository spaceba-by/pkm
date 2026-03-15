import Foundation

@testable import PKMSync

final class MockConflictService: ConflictServiceProtocol, @unchecked Sendable {
    var conflicts: [ConflictFile] = []
    private(set) var scanCallCount = 0
    private(set) var resolveCallCount = 0
    private(set) var lastResolution: ConflictResolution?

    func scanForConflicts(in vaultPath: String) async throws -> [ConflictFile] {
        scanCallCount += 1
        return conflicts
    }

    func resolveConflict(_ conflict: ConflictFile, resolution: ConflictResolution) throws {
        resolveCallCount += 1
        lastResolution = resolution
    }
}
