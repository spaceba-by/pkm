@testable import PKMSync
import XCTest

final class SyncServiceTests: XCTestCase {
    private var mockRunner: MockProcessRunner!
    private var configuration: SyncConfiguration!
    private var defaults: UserDefaults!
    private var sut: SyncService!

    override func setUp() {
        super.setUp()
        mockRunner = MockProcessRunner()
        defaults = UserDefaults(suiteName: "SyncServiceTests")!
        defaults.removePersistentDomain(forName: "SyncServiceTests")
        configuration = SyncConfiguration(defaults: defaults)
        configuration.vaultPath = "/Users/test/vault"
        configuration.bucketName = "test-bucket"
        configuration.rclonePath = "/usr/bin/true"
        sut = SyncService(configuration: configuration, processRunner: mockRunner)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SyncServiceTests")
        super.tearDown()
    }

    func testSyncBuildsCorrectArguments() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "Transferred:            0 / 0, -\nChecks:                 5 / 5, 100%\nElapsed time:        1s",
            stderr: "",
            exitCode: 0
        ))

        _ = try await sut.sync()

        XCTAssertEqual(mockRunner.lastArguments[0], "bisync")
        XCTAssertEqual(mockRunner.lastArguments[1], "/Users/test/vault")
        XCTAssertEqual(mockRunner.lastArguments[2], "pkm-s3:test-bucket")
        XCTAssertTrue(mockRunner.lastArguments.contains("--conflict-resolve"))
        XCTAssertTrue(mockRunner.lastArguments.contains("--recover"))
        XCTAssertTrue(mockRunner.lastArguments.contains("--resilient"))
        XCTAssertTrue(mockRunner.lastArguments.contains("--max-lock"))
        XCTAssertTrue(mockRunner.lastArguments.contains("--verbose"))
    }

    func testSyncWithFilterFile() async throws {
        configuration.filterFilePath = "/Users/test/.config/rclone/filterlist.txt"
        sut = SyncService(configuration: configuration, processRunner: mockRunner)

        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        XCTAssertTrue(mockRunner.lastArguments.contains("--filter-from"))
        XCTAssertTrue(mockRunner.lastArguments.contains("/Users/test/.config/rclone/filterlist.txt"))
    }

    func testResyncUsesResyncFlag() async throws {
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.resync()

        XCTAssertTrue(mockRunner.lastArguments.contains("--resync"))
        XCTAssertFalse(mockRunner.lastArguments.contains("--recover"))
        XCTAssertFalse(mockRunner.lastArguments.contains("--resilient"))
    }

    func testSyncReturnsSuccessEntry() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "Transferred:            3 / 3, 100%\nChecks:                10 / 10, 100%",
            stderr: "",
            exitCode: 0
        ))

        let entry = try await sut.sync()

        XCTAssertTrue(entry.success)
        XCTAssertEqual(entry.filesTransferred, 3)
        XCTAssertEqual(entry.filesChecked, 10)
        XCTAssertNil(entry.errorMessage)
    }

    func testSyncReturnsFailureOnNonZeroExit() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "",
            stderr: "ERROR : bisync aborted",
            exitCode: 1
        ))

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        XCTAssertNotNil(entry.errorMessage)
    }

    func testSyncReportsBisyncFailureReason() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "",
            stderr: """
            2026/08/17 17:52:53 INFO  : Setting --ignore-listing-checksum as neither \
            --checksum nor --compare checksum are set.
            2026/08/17 17:52:53 NOTICE: Failed to bisync: prior lock file found
            """,
            exitCode: 1
        ))

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        XCTAssertEqual(entry.errorMessage, "Failed to bisync: prior lock file found")
    }

    /// Falling back to the head of stderr showed rclone's opening INFO line as
    /// the cause of every unrecognised failure.
    func testSyncFallsBackToExitCodeRatherThanStderrHead() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "",
            stderr: """
            2026/08/17 17:52:53 INFO  : Setting --ignore-listing-checksum as neither \
            --checksum nor --compare checksum are set.
            """,
            exitCode: 2
        ))

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        XCTAssertEqual(entry.errorMessage, "rclone exited with code 2")
    }

    func testSyncStoresRawOutputOnFailure() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "Transferred: 0 / 0, -\nChecks: 5 / 5, 100%",
            stderr: "ERROR : bisync aborted\nERROR : something else went wrong",
            exitCode: 1
        ))

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        let rawOutput = try XCTUnwrap(entry.rawOutput)
        XCTAssertTrue(rawOutput.contains("bisync aborted"))
        XCTAssertTrue(rawOutput.contains("something else went wrong"))
        XCTAssertTrue(rawOutput.contains("Transferred"))
    }

    func testSyncStoresRawOutputOnSuccess() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "Transferred:            3 / 3, 100%\nChecks:                10 / 10, 100%",
            stderr: "",
            exitCode: 0
        ))

        let entry = try await sut.sync()

        XCTAssertTrue(entry.success)
        let rawOutput = try XCTUnwrap(entry.rawOutput)
        XCTAssertTrue(rawOutput.contains("Transferred"))
    }

    func testSyncAutoRetriesWithResyncOnMissingListings() async throws {
        mockRunner.results = [
            .success(ProcessOutput(
                stdout: "",
                // swiftlint:disable:next line_length
                stderr: "2026/03/17 09:08:52 ERROR : Bisync critical error: cannot find prior Path1 or Path2 listings, likely due to critical error on prior run",
                exitCode: 1
            )),
            .success(ProcessOutput(
                stdout: "Transferred:            0 / 0, -\nChecks:                 5 / 5, 100%",
                stderr: "",
                exitCode: 0
            )),
        ]

        let entry = try await sut.sync()

        XCTAssertTrue(entry.success)
        XCTAssertEqual(mockRunner.runCallCount, 2)
        XCTAssertFalse(mockRunner.allArguments[0].contains("--resync"))
        XCTAssertTrue(mockRunner.allArguments[1].contains("--resync"))
    }

    func testSyncDoesNotRetryOnOtherErrors() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "",
            stderr: "ERROR : bisync aborted",
            exitCode: 1
        ))

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        XCTAssertEqual(mockRunner.runCallCount, 1)
    }

    func testThrowsWhenNotConfigured() async {
        configuration.vaultPath = ""

        do {
            _ = try await sut.sync()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is SyncError)
        }
    }

    // MARK: - Progress

    func testSyncRequestsPeriodicStatsAndDisablesColour() async throws {
        _ = try await sut.sync()

        let args = mockRunner.lastArguments
        let statsIndex = try XCTUnwrap(args.firstIndex(of: "--stats"))
        XCTAssertEqual(args[statsIndex + 1], "1s")

        let colorIndex = try XCTUnwrap(args.firstIndex(of: "--color"))
        XCTAssertEqual(args[colorIndex + 1], "NEVER")
    }

    func testSyncWithoutProgressHandlerPassesNoneToRunner() async throws {
        _ = try await sut.sync()

        XCTAssertFalse(
            mockRunner.receivedOutputHandler,
            "Streaming should stay off when nobody is listening"
        )
    }

    func testSyncReportsProgressFromStreamedOutput() async throws {
        mockRunner.streamedLines = [
            "2026/08/12 11:37:28 INFO  : Applying changes",
            "2026/08/12 11:37:28 INFO  : notes/file1.md: Copied (new)",
            "Transferred:   \t    4.215 MiB / 38.147 MiB, 11%, 2.014 MiB/s, ETA 16s",
            "Transferred:            1 / 3, 33%",
        ]
        let collected = ProgressCollector()

        _ = try await sut.sync { collected.append($0) }

        let updates = collected.updates
        XCTAssertFalse(updates.isEmpty)

        let last = try XCTUnwrap(updates.last)
        XCTAssertEqual(last.phase, .applyingChanges)
        XCTAssertEqual(last.currentObject, "notes/file1.md")
        XCTAssertEqual(last.filesDone, 1)
        XCTAssertEqual(last.filesTotal, 3)
        XCTAssertEqual(last.speed, "2.014 MiB/s")
        XCTAssertEqual(last.eta, "16s")
    }

    func testResyncRetryStartsWithCleanProgress() async throws {
        mockRunner.results = [
            .success(ProcessOutput(
                stdout: "",
                // swiftlint:disable:next line_length
                stderr: "2026/03/17 09:08:52 ERROR : Bisync critical error: cannot find prior Path1 or Path2 listings, likely due to critical error on prior run",
                exitCode: 1
            )),
            .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0)),
        ]
        mockRunner.streamedLines = ["2026/08/12 11:37:28 INFO  : Building Path1 and Path2 listings"]
        let collected = ProgressCollector()

        _ = try await sut.sync { collected.append($0) }

        XCTAssertEqual(mockRunner.runCallCount, 2)
        XCTAssertEqual(
            collected.updates.last?.phase,
            .buildingListings,
            "The retry should report its own progress"
        )
    }
}

/// `SyncService` reports progress from whichever thread drained the output.
private final class ProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [SyncProgress] = []

    var updates: [SyncProgress] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ progress: SyncProgress) {
        lock.lock()
        storage.append(progress)
        lock.unlock()
    }
}
