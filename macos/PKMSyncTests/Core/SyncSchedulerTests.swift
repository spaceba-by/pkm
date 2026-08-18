@testable import PKMSync
import XCTest

@MainActor
final class SyncSchedulerTests: XCTestCase {
    private var mockService: MockSyncService!
    private var configuration: SyncConfiguration!
    private var defaults: UserDefaults!
    private var sut: SyncScheduler!

    /// Async variants inherit the class's `@MainActor`; the synchronous ones are
    /// nonisolated overrides, so touching the isolated properties below warns.
    override func setUp() async throws {
        try await super.setUp()
        mockService = MockSyncService()
        defaults = UserDefaults(suiteName: "SyncSchedulerTests")!
        defaults.removePersistentDomain(forName: "SyncSchedulerTests")
        configuration = SyncConfiguration(defaults: defaults)
        configuration.syncIntervalMinutes = 1
        sut = SyncScheduler(syncService: mockService, configuration: configuration)
    }

    override func tearDown() async throws {
        sut.stop()
        defaults.removePersistentDomain(forName: "SyncSchedulerTests")
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(sut.status, .idle)
        XCTAssertTrue(sut.recentLogs.isEmpty)
        XCTAssertNil(sut.lastSyncDate)
    }

    func testStartSetsRunning() {
        sut.start()
        XCTAssertTrue(sut.isRunning)
    }

    func testStopClearsRunning() {
        sut.start()
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }

    func testSyncNowPerformsSync() async {
        mockService.syncResult = .success(SyncLogEntry(filesTransferred: 2, success: true))

        await sut.syncNow()

        XCTAssertEqual(mockService.syncCallCount, 1)
        XCTAssertEqual(sut.recentLogs.count, 1)
        XCTAssertEqual(sut.status, .idle)
        XCTAssertNotNil(sut.lastSyncDate)
    }

    func testSyncNowRecordsError() async {
        mockService.syncResult = .failure(SyncError.rcloneNotFound)

        await sut.syncNow()

        XCTAssertEqual(sut.recentLogs.count, 1)
        XCTAssertFalse(sut.recentLogs[0].success)
        if case .error = sut.status {
            // Expected
        } else {
            XCTFail("Expected error status")
        }
    }

    func testSyncNowRecordsFailedEntry() async {
        mockService.syncResult = .success(
            SyncLogEntry(success: false, errorMessage: "bisync aborted")
        )

        await sut.syncNow()

        XCTAssertEqual(sut.recentLogs.count, 1)
        XCTAssertFalse(sut.recentLogs[0].success)
        if case let .error(msg) = sut.status {
            XCTAssertEqual(msg, "bisync aborted")
        } else {
            XCTFail("Expected error status")
        }
    }

    func testSyncNowPublishesProgressThenSettles() async {
        var inFlight = SyncProgress()
        inFlight.phase = .applyingChanges
        inFlight.currentObject = "notes/file1.md"
        mockService.progressUpdates = [inFlight]

        await sut.syncNow()

        XCTAssertEqual(
            sut.status,
            .idle,
            "Progress must not leave the status stuck on syncing"
        )
    }

    func testStatusCarriesProgressWhileSyncing() async {
        var inFlight = SyncProgress()
        inFlight.phase = .applyingChanges
        inFlight.currentObject = "notes/file1.md"
        inFlight.filesDone = 1
        inFlight.filesTotal = 3
        mockService.progressUpdates = [inFlight]

        // Hold the sync open so the in-flight status is observable.
        let gate = AsyncGate()
        mockService.gate = gate

        let syncTask = Task { await sut.syncNow() }

        let observed = await waitForProgress { $0.phase == .applyingChanges }

        XCTAssertEqual(observed?.currentObject, "notes/file1.md")
        XCTAssertEqual(observed?.filesDone, 1)
        XCTAssertEqual(observed?.filesTotal, 3)

        await gate.open()
        await syncTask.value
        XCTAssertEqual(sut.status, .idle)
    }

    // MARK: - Serialization

    /// rclone bisync locks per path pair, so a second run started mid-sync dies
    /// on that lock — and used to reset the live progress on its way out.
    func testOverlappingSyncIsSkipped() async {
        var inFlight = SyncProgress()
        inFlight.phase = .applyingChanges
        inFlight.currentObject = "notes/file1.md"
        mockService.progressUpdates = [inFlight]

        let gate = AsyncGate()
        mockService.gate = gate

        let running = Task { await sut.syncNow() }
        _ = await waitForProgress { $0.phase == .applyingChanges }

        await sut.syncNow()

        XCTAssertEqual(mockService.syncCallCount, 1, "A second rclone must not be launched")
        XCTAssertEqual(
            sut.status.progress?.currentObject,
            "notes/file1.md",
            "The skipped request must not reset the live progress"
        )
        XCTAssertTrue(sut.recentLogs.isEmpty, "A skipped request is not a sync outcome")

        await gate.open()
        await running.value

        XCTAssertEqual(mockService.syncCallCount, 1)
        XCTAssertEqual(sut.recentLogs.count, 1)
        XCTAssertEqual(sut.status, .idle)
    }

    func testIsSyncInFlightSpansTheRun() async {
        XCTAssertFalse(sut.isSyncInFlight)

        let gate = AsyncGate()
        mockService.gate = gate
        mockService.progressUpdates = [SyncProgress()]

        let running = Task { await sut.syncNow() }
        _ = await waitForProgress { _ in true }

        XCTAssertTrue(sut.isSyncInFlight)

        await gate.open()
        await running.value

        XCTAssertFalse(sut.isSyncInFlight)
    }

    /// A run that fails leaves `status == .error`, so the flag is what the
    /// "Sync Now" button has to key off to stay disabled.
    func testIsSyncInFlightClearsAfterFailure() async {
        mockService.syncResult = .failure(SyncError.rcloneNotFound)

        await sut.syncNow()

        XCTAssertFalse(sut.isSyncInFlight)
    }

    func testLogsOrderedByStartTimeNewestFirst() async {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)

        // A long run started first but finishing last must not jump to the top.
        mockService.syncResult = .success(SyncLogEntry(timestamp: late, success: true))
        await sut.syncNow()
        mockService.syncResult = .success(SyncLogEntry(timestamp: early, success: true))
        await sut.syncNow()

        XCTAssertEqual(sut.recentLogs.map(\.timestamp), [late, early])
    }

    /// The scheduler funnels progress through an `AsyncStream`, so updates land a
    /// hop later than the service reporting them.
    private func waitForProgress(
        timeout: TimeInterval = 2,
        where predicate: (SyncProgress) -> Bool
    ) async -> SyncProgress? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let progress = sut.status.progress, predicate(progress) {
                return progress
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return nil
    }

    func testLogsTrimmedToMax() async {
        for _ in 0 ..< 55 {
            await sut.syncNow()
        }

        XCTAssertLessThanOrEqual(sut.recentLogs.count, configuration.maxLogEntries)
    }
}
