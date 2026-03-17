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
}
