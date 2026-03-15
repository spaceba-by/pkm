@testable import PKMSync
import XCTest

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var configuration: SyncConfiguration!
    private var mockConflictService: MockConflictService!
    private var mockSyncService: MockSyncService!
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

        let scheduler = SyncScheduler(
            syncService: mockSyncService,
            configuration: configuration
        )
        sut = MenuBarViewModel(
            configuration: configuration,
            scheduler: scheduler,
            conflictService: mockConflictService
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
}
