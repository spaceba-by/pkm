import Foundation
@testable import PKMSync

final class MockSyncService: SyncServiceProtocol, @unchecked Sendable {
    var syncResult: Result<SyncLogEntry, Error> = .success(SyncLogEntry())
    var resyncResult: Result<SyncLogEntry, Error> = .success(SyncLogEntry())
    private(set) var syncCallCount = 0
    private(set) var resyncCallCount = 0

    func sync() async throws -> SyncLogEntry {
        syncCallCount += 1
        return try syncResult.get()
    }

    func resync() async throws -> SyncLogEntry {
        resyncCallCount += 1
        return try resyncResult.get()
    }
}
