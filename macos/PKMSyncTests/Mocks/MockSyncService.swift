import Foundation
@testable import PKMSync

/// A one-shot gate letting a test hold a mocked sync open long enough to observe
/// the in-flight state it publishes.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

final class MockSyncService: SyncServiceProtocol, @unchecked Sendable {
    var syncResult: Result<SyncLogEntry, Error> = .success(SyncLogEntry())
    var resyncResult: Result<SyncLogEntry, Error> = .success(SyncLogEntry())
    /// Snapshots reported to `onProgress` before returning.
    var progressUpdates: [SyncProgress] = []
    /// When set, the mock waits on this gate after reporting progress.
    var gate: AsyncGate?
    private(set) var syncCallCount = 0
    private(set) var resyncCallCount = 0

    func sync(onProgress: (@Sendable (SyncProgress) -> Void)?) async throws -> SyncLogEntry {
        syncCallCount += 1
        await report(to: onProgress)
        return try syncResult.get()
    }

    func resync(onProgress: (@Sendable (SyncProgress) -> Void)?) async throws -> SyncLogEntry {
        resyncCallCount += 1
        await report(to: onProgress)
        return try resyncResult.get()
    }

    private func report(to onProgress: (@Sendable (SyncProgress) -> Void)?) async {
        if let onProgress {
            for update in progressUpdates {
                onProgress(update)
            }
        }
        await gate?.wait()
    }
}
