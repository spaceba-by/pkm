import XCTest

@testable import PKMSync

@MainActor
final class SyncSchedulerTests: XCTestCase {
    private var mockService: MockSyncService!
    private var configuration: SyncConfiguration!
    private var defaults: UserDefaults!
    private var sut: SyncScheduler!

    override func setUp() {
        super.setUp()
        mockService = MockSyncService()
        defaults = UserDefaults(suiteName: "SyncSchedulerTests")!
        defaults.removePersistentDomain(forName: "SyncSchedulerTests")
        configuration = SyncConfiguration(defaults: defaults)
        configuration.syncIntervalMinutes = 1
        sut = SyncScheduler(syncService: mockService, configuration: configuration)
    }

    override func tearDown() {
        sut.stop()
        defaults.removePersistentDomain(forName: "SyncSchedulerTests")
        super.tearDown()
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
        if case .error(let msg) = sut.status {
            XCTAssertEqual(msg, "bisync aborted")
        } else {
            XCTFail("Expected error status")
        }
    }

    func testLogsTrimmedToMax() async {
        configuration.syncIntervalMinutes = 1
        let testConfig = SyncConfiguration(defaults: defaults)
        testConfig.syncIntervalMinutes = 1

        for _ in 0 ..< 55 {
            await sut.syncNow()
        }

        XCTAssertLessThanOrEqual(sut.recentLogs.count, configuration.maxLogEntries)
    }
}
