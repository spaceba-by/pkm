@testable import PKMSync
import XCTest

final class SyncServiceTests: XCTestCase {
    private var mockRunner: MockProcessRunner!
    private var configuration: SyncConfiguration!
    private var defaults: UserDefaults!
    private var tempDirectory: URL!
    private var sut: SyncService!

    /// Arguments for the bisync phase (always the first rclone invocation).
    private var bisyncArguments: [String] { mockRunner.allArguments[0] }

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockRunner = MockProcessRunner()
        defaults = UserDefaults(suiteName: "SyncServiceTests")!
        defaults.removePersistentDomain(forName: "SyncServiceTests")

        // Point the managed filters file at a temp dir so the service does not
        // create one in the real Application Support directory.
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        configuration = SyncConfiguration(defaults: defaults)
        configuration.vaultPath = "/Users/test/vault"
        configuration.bucketName = "test-bucket"
        configuration.rclonePath = "/usr/bin/true"
        configuration.filterFilePath = tempDirectory.appendingPathComponent("filter.txt").path
        sut = SyncService(configuration: configuration, processRunner: mockRunner)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: "SyncServiceTests")
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }

    func testSyncBuildsCorrectArguments() async throws {
        mockRunner.result = .success(ProcessOutput(
            stdout: "Transferred:            0 / 0, -\nChecks:                 5 / 5, 100%\nElapsed time:        1s",
            stderr: "",
            exitCode: 0
        ))

        _ = try await sut.sync()

        XCTAssertEqual(bisyncArguments[0], "bisync")
        XCTAssertEqual(bisyncArguments[1], "/Users/test/vault")
        XCTAssertEqual(bisyncArguments[2], "pkm-s3:test-bucket")
        XCTAssertTrue(bisyncArguments.contains("--conflict-resolve"))
        XCTAssertTrue(bisyncArguments.contains("--conflict-loser"))
        XCTAssertTrue(bisyncArguments.contains("--recover"))
        XCTAssertTrue(bisyncArguments.contains("--resilient"))
        XCTAssertTrue(bisyncArguments.contains("--max-lock"))
        XCTAssertTrue(bisyncArguments.contains("--verbose"))
    }

    // bisync only enforces its filter-change guard (MD5 of the filters file,
    // abort demanding --resync) for --filters-file. With --filter-from, newly
    // excluded files look deleted and get deleted for real on both sides.
    func testSyncUsesFiltersFileNotFilterFrom() async throws {
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        XCTAssertTrue(bisyncArguments.contains("--filters-file"))
        XCTAssertFalse(bisyncArguments.contains("--filter-from"))
        XCTAssertTrue(bisyncArguments.contains(configuration.filterFilePath))
    }

    func testSyncCreatesManagedFilterFileExcludingAgent() async throws {
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        let contents = try String(contentsOfFile: configuration.filterFilePath, encoding: .utf8)
        XCTAssertTrue(contents.contains("- /_agent/**"))
    }

    func testSyncDoesNotOverwriteExistingFilterFile() async throws {
        let custom = "- /custom/**\n"
        try custom.write(toFile: configuration.filterFilePath, atomically: true, encoding: .utf8)
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        let contents = try String(contentsOfFile: configuration.filterFilePath, encoding: .utf8)
        XCTAssertEqual(contents, custom)
    }

    func testSyncPullsAgentPrefixOneWay() async throws {
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        XCTAssertEqual(mockRunner.runCallCount, 2)
        let pull = mockRunner.allArguments[1]
        XCTAssertEqual(pull[0], "copy")
        XCTAssertEqual(pull[1], "pkm-s3:test-bucket/_agent")
        XCTAssertEqual(pull[2], "/Users/test/vault/_agent")
        XCTAssertTrue(pull.contains("--use-server-modtime"))
        XCTAssertTrue(pull.contains("search/vector-index.json"))
        XCTAssertTrue(pull.contains("dispatch/**"))
        // The pull must never push: bisync is the only bidirectional phase.
        XCTAssertFalse(pull.contains("bisync"))
        XCTAssertFalse(pull.contains("sync"))
    }

    func testAgentPullCanBeDisabled() async throws {
        configuration.agentPullEnabled = false
        sut = SyncService(configuration: configuration, processRunner: mockRunner)
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.sync()

        XCTAssertEqual(mockRunner.runCallCount, 1)
    }

    func testFailedAgentPullFailsTheSync() async throws {
        mockRunner.results = [
            .success(ProcessOutput(stdout: "Transferred:  2 / 2, 100%", stderr: "", exitCode: 0)),
            .success(ProcessOutput(stdout: "", stderr: "ERROR : directory not found", exitCode: 3)),
        ]

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        let message = try XCTUnwrap(entry.errorMessage)
        XCTAssertTrue(message.contains("_agent pull"))
        // bisync's work is still reported even though the pull failed.
        XCTAssertEqual(entry.filesTransferred, 2)
    }

    func testResyncUsesResyncFlag() async throws {
        mockRunner.result = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))

        _ = try await sut.resync()

        XCTAssertTrue(bisyncArguments.contains("--resync"))
        XCTAssertFalse(bisyncArguments.contains("--recover"))
        XCTAssertFalse(bisyncArguments.contains("--resilient"))
    }

    func testSyncSumsCountsAcrossPhases() async throws {
        mockRunner.results = [
            .success(ProcessOutput(
                stdout: "Transferred:            3 / 3, 100%\nChecks:                10 / 10, 100%",
                stderr: "",
                exitCode: 0
            )),
            .success(ProcessOutput(
                stdout: "Transferred:            2 / 2, 100%\nChecks:                 4 / 4, 100%",
                stderr: "",
                exitCode: 0
            )),
        ]

        let entry = try await sut.sync()

        XCTAssertTrue(entry.success)
        XCTAssertEqual(entry.filesTransferred, 5)
        XCTAssertEqual(entry.filesChecked, 14)
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
        XCTAssertEqual(entry.errorMessage, "bisync: Failed to bisync: prior lock file found")
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
        XCTAssertEqual(entry.errorMessage, "bisync: rclone exited with code 2")
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
        // bisync, retried bisync, then the _agent pull.
        XCTAssertEqual(mockRunner.runCallCount, 3)
        XCTAssertFalse(mockRunner.allArguments[0].contains("--resync"))
        XCTAssertTrue(mockRunner.allArguments[1].contains("--resync"))
        XCTAssertEqual(mockRunner.allArguments[2][0], "copy")
    }

    func testSyncDoesNotRetryOnOtherErrors() async throws {
        mockRunner.results = [
            .success(ProcessOutput(stdout: "", stderr: "ERROR : bisync aborted", exitCode: 1)),
            .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0)),
        ]

        let entry = try await sut.sync()

        XCTAssertFalse(entry.success)
        // One bisync attempt (no retry) plus the _agent pull.
        XCTAssertEqual(mockRunner.runCallCount, 2)
        XCTAssertFalse(mockRunner.allArguments[0].contains("--resync"))
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

        let args = bisyncArguments
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

        // bisync, retried bisync, then the _agent pull.
        XCTAssertEqual(mockRunner.runCallCount, 3)
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
