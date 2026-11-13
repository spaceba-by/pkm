@testable import PKMSync
import XCTest

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var configuration: SyncConfiguration!
    private var mockConflictService: MockConflictService!
    private var mockSyncService: MockSyncService!
    private var mockUpdateService: MockUpdateService!
    private var mockInstaller: MockUpdateInstaller!
    private var sut: MenuBarViewModel!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "MenuBarViewModelTests")!
        defaults.removePersistentDomain(forName: "MenuBarViewModelTests")
        configuration = SyncConfiguration(defaults: defaults)
        configuration.vaultPath = "/Users/test/vault"
        configuration.bucketName = "test-bucket"
        mockConflictService = MockConflictService()
        mockSyncService = MockSyncService()
        mockUpdateService = MockUpdateService()
        mockInstaller = MockUpdateInstaller()
        let installer: MockUpdateInstaller = mockInstaller

        let scheduler = SyncScheduler(
            syncService: mockSyncService,
            configuration: configuration
        )
        sut = MenuBarViewModel(
            configuration: configuration,
            scheduler: scheduler,
            conflictService: mockConflictService,
            updateService: mockUpdateService,
            installUpdate: { try await installer.install($0) }
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "MenuBarViewModelTests")
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

    func testCheckForUpdatesWhenUpdateAvailable() async throws {
        let update = try AppUpdate(
            version: "1.1.0",
            releaseNotes: "New feature",
            downloadURL: XCTUnwrap(URL(string: "https://example.com/update.zip")),
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

    func testInstallFailureKeepsBackupPathWhenRollbackFails() {
        let error = UpdateError.rollbackFailed(
            installError: "disk full",
            rollbackError: "permission denied",
            backupPath: "/Applications/PKMSync.backup.app"
        )

        let state = MenuBarViewModel.installFailureState(for: error)

        XCTAssertEqual(
            state,
            .recoveryNeeded(
                message: error.localizedDescription,
                backupPath: "/Applications/PKMSync.backup.app"
            )
        )
    }

    func testInstallFailureWithoutRollbackIsPlainError() {
        let error = UpdateError.installFailed("Failed to replace app: disk full")

        let state = MenuBarViewModel.installFailureState(for: error)

        XCTAssertEqual(state, .error(message: error.localizedDescription))
    }

    // MARK: - Recovery Latch

    func testCheckAfterRollbackFailureKeepsRecoveryState() async throws {
        let recovery = try await driveToRollbackFailure()

        await sut.checkForUpdates(force: true)

        XCTAssertEqual(sut.updateState, recovery)
        XCTAssertEqual(mockUpdateService.checkCallCount, 1, "A check must not run while recovery is needed")
    }

    func testCheckInFlightDuringRollbackFailureKeepsRecoveryState() async throws {
        mockUpdateService.checkResult = try .success(makeUpdate())
        await sut.checkForUpdates()
        await sut.downloadAndInstall()
        XCTAssertEqual(sut.updateState, .readyToInstall)

        let gate = AsyncGate()
        mockUpdateService.checkGate = gate
        let viewModel: MenuBarViewModel = sut
        let check = Task { await viewModel.checkForUpdates(force: true) }
        await waitUntil("the check reaches the service") { mockUpdateService.checkCallCount == 2 }
        XCTAssertEqual(sut.updateState, .checking)

        mockInstaller.installResult = .failure(rollbackError)
        await sut.downloadAndInstall()
        let recovery = sut.updateState
        XCTAssertTrue(sut.needsRecovery)

        await gate.open()
        await check.value

        XCTAssertEqual(sut.updateState, recovery)
    }

    func testRollbackFailureDoesNotOfferAnotherInstall() async throws {
        let recovery = try await driveToRollbackFailure()

        await sut.downloadAndInstall()

        XCTAssertEqual(sut.updateState, recovery)
        XCTAssertEqual(mockUpdateService.downloadCallCount, 1)
        XCTAssertEqual(mockInstaller.installCallCount, 1)
    }

    func testCheckDuringInstallIsSkipped() async throws {
        mockUpdateService.checkResult = try .success(makeUpdate())
        await sut.checkForUpdates()
        await sut.downloadAndInstall()

        let gate = AsyncGate()
        mockInstaller.installGate = gate
        let viewModel: MenuBarViewModel = sut
        let install = Task { await viewModel.downloadAndInstall() }
        await waitUntil("the install starts") { mockInstaller.installCallCount == 1 }

        await sut.checkForUpdates(force: true)
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)
        XCTAssertEqual(sut.updateState, .readyToInstall)

        await gate.open()
        await install.value
    }

    func testCheckFinishingDuringInstallKeepsInstallRow() async throws {
        mockUpdateService.checkResult = try .success(makeUpdate())
        await sut.checkForUpdates()
        await sut.downloadAndInstall()

        let checkGate = AsyncGate()
        mockUpdateService.checkGate = checkGate
        let viewModel: MenuBarViewModel = sut
        let check = Task { await viewModel.checkForUpdates(force: true) }
        await waitUntil("the check reaches the service") { mockUpdateService.checkCallCount == 2 }

        let installGate = AsyncGate()
        mockInstaller.installGate = installGate
        let install = Task { await viewModel.downloadAndInstall() }
        await waitUntil("the install starts") { mockInstaller.installCallCount == 1 }
        XCTAssertEqual(sut.updateState, .readyToInstall)

        await checkGate.open()
        await check.value
        XCTAssertEqual(sut.updateState, .readyToInstall, "A check finishing mid-install must not replace the row")

        await installGate.open()
        await install.value
    }

    func testFailedCheckFinishingDuringInstallKeepsInstallRow() async throws {
        mockUpdateService.checkResult = try .success(makeUpdate())
        await sut.checkForUpdates()
        await sut.downloadAndInstall()

        let checkGate = AsyncGate()
        mockUpdateService.checkGate = checkGate
        mockUpdateService.checkResult = .failure(UpdateError.networkError("timeout"))
        let viewModel: MenuBarViewModel = sut
        let check = Task { await viewModel.checkForUpdates(force: true) }
        await waitUntil("the check reaches the service") { mockUpdateService.checkCallCount == 2 }

        let installGate = AsyncGate()
        mockInstaller.installGate = installGate
        let install = Task { await viewModel.downloadAndInstall() }
        await waitUntil("the install starts") { mockInstaller.installCallCount == 1 }

        await checkGate.open()
        await check.value
        XCTAssertEqual(sut.updateState, .readyToInstall)

        await installGate.open()
        await install.value
    }

    func testCheckForUpdatesRateLimits() async {
        mockUpdateService.checkResult = .success(nil)

        await sut.checkForUpdates()
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)

        // Second call within 5 minutes should be skipped
        await sut.checkForUpdates()
        XCTAssertEqual(mockUpdateService.checkCallCount, 1)
    }

    // MARK: - Helpers

    private var rollbackError: UpdateError {
        .rollbackFailed(
            installError: "disk full",
            rollbackError: "permission denied",
            backupPath: "/Applications/PKMSync.backup.app"
        )
    }

    private func makeUpdate() throws -> AppUpdate {
        try AppUpdate(
            version: "1.1.0",
            releaseNotes: "New feature",
            downloadURL: XCTUnwrap(URL(string: "https://example.com/update.zip")),
            publishedAt: Date(),
            assetSize: 5_000_000
        )
    }

    /// Check, download, then an install whose rollback fails. Returns the recovery state it left.
    private func driveToRollbackFailure() async throws -> UpdateState {
        mockUpdateService.checkResult = try .success(makeUpdate())
        await sut.checkForUpdates()
        await sut.downloadAndInstall()
        mockInstaller.installResult = .failure(rollbackError)
        await sut.downloadAndInstall()

        let expected = UpdateState.recoveryNeeded(
            message: rollbackError.localizedDescription,
            backupPath: "/Applications/PKMSync.backup.app"
        )
        XCTAssertEqual(sut.updateState, expected)
        return expected
    }

    /// The mocks count a call before they wait on their gate, so a count shows the call is held there.
    private func waitUntil(_ what: String, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition(), "Timed out waiting until \(what)")
    }
}
