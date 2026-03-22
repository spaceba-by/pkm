@testable import PKMSync
import XCTest

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var configuration: SyncConfiguration!
    private var mockConflictService: MockConflictService!
    private var mockSyncService: MockSyncService!
    private var mockUpdateService: MockUpdateService!
    private var sut: MenuBarViewModel!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MenuBarViewModelTests")!
        defaults.removePersistentDomain(forName: "MenuBarViewModelTests")
        configuration = SyncConfiguration(defaults: defaults)
        configuration.vaultPath = "/Users/test/vault"
        configuration.bucketName = "test-bucket"
        mockConflictService = MockConflictService()
        mockSyncService = MockSyncService()
        mockUpdateService = MockUpdateService()

        let scheduler = SyncScheduler(
            syncService: mockSyncService,
            configuration: configuration
        )
        sut = MenuBarViewModel(
            configuration: configuration,
            scheduler: scheduler,
            conflictService: mockConflictService,
            updateService: mockUpdateService
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "MenuBarViewModelTests")
        super.tearDown()
    }

    func testInitialStatus() {
        XCTAssertEqual(sut.status, .idle)
        XCTAssertTrue(sut.recentLogs.isEmpty)
        XCTAssertFalse(sut.hasConflicts)
    }

    func testInitialUpdateState() {
        XCTAssertEqual(sut.updateState, .idle)
        XCTAssertNil(sut.availableUpdate)
    }

    func testSyncNowTriggersSync() async {
        await sut.syncNow()

        XCTAssertEqual(mockSyncService.syncCallCount, 1)
    }

    func testRefreshConflicts() async {
        mockConflictService.conflicts = [
            ConflictFile(originalPath: "/vault/note.md", conflictPath: "/vault/note.conflict1.md"),
        ]

        await sut.refreshConflicts()

        XCTAssertTrue(sut.hasConflicts)
        XCTAssertEqual(sut.conflicts.count, 1)
    }

    func testResolveConflict() async {
        let conflict = ConflictFile(
            originalPath: "/vault/note.md",
            conflictPath: "/vault/note.conflict1.md"
        )
        mockConflictService.conflicts = [conflict]
        await sut.refreshConflicts()

        sut.resolveConflict(sut.conflicts[0], resolution: .keepOriginal)

        XCTAssertEqual(mockConflictService.resolveCallCount, 1)
        XCTAssertFalse(sut.hasConflicts)
    }

    func testShowDiffSetsSelectedConflict() async {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault/note.md",
            conflictPath: "/Users/test/vault/note.conflict1.md"
        )
        mockConflictService.conflicts = [conflict]
        await sut.refreshConflicts()

        sut.showDiff(for: sut.conflicts[0])

        XCTAssertNotNil(sut.selectedConflict)
        XCTAssertEqual(sut.selectedConflict?.originalPath, "/Users/test/vault/note.md")
    }

    // MARK: - Update Tests

    func testCheckForUpdatesWhenUpdateAvailable() async {
        let update = AppUpdate(
            version: "1.1.0",
            releaseNotes: "New feature",
            downloadURL: URL(string: "https://example.com/update.zip")!,
            publishedAt: Date(),
            assetSize: 5_000_000
        )
        mockUpdateService.checkResult = .success(update)

        await sut.checkForUpdates()

        XCTAssertEqual(sut.updateState, .available(version: "1.1.0"))
        XCTAssertNotNil(sut.availableUpdate)
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)
    }

    func testCheckForUpdatesWhenUpToDate() async {
        mockUpdateService.checkResult = .success(nil)

        await sut.checkForUpdates()

        XCTAssertEqual(sut.updateState, .upToDate)
        XCTAssertNil(sut.availableUpdate)
    }

    func testCheckForUpdatesOnError() async {
        mockUpdateService.checkResult = .failure(UpdateError.networkError("timeout"))

        await sut.checkForUpdates()

        if case .error = sut.updateState {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.updateState)")
        }
    }

    func testCheckForUpdatesRateLimits() async {
        mockUpdateService.checkResult = .success(nil)

        await sut.checkForUpdates()
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)

        // Second call within 5 minutes should be skipped
        await sut.checkForUpdates()
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)
    }
}
