@testable import PKMSync
import XCTest

final class RcloneOutputParserTests: XCTestCase {
    func testParsesTransferredFiles() {
        let stdout = """
        Transferred:      1.234 MiB / 1.234 MiB, 100%, 500 KiB/s, ETA 0s
        Transferred:            3 / 3, 100%
        Elapsed time:        2.5s
        """
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.filesTransferred, 3)
    }

    func testParsesChecks() {
        let stdout = """
        Checks:               150 / 150, 100%
        Transferred:            2 / 2, 100%
        Elapsed time:        1.2s
        """
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.filesChecked, 150)
        XCTAssertEqual(result.filesTransferred, 2)
    }

    func testParsesElapsedTime() {
        let stdout = "Elapsed time:        3.456s"
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.elapsedSeconds, 3.456, accuracy: 0.001)
    }

    func testParsesMinutesAndSeconds() {
        let stdout = "Elapsed time:     1m30.5s"
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.elapsedSeconds, 90.5, accuracy: 0.001)
    }

    func testParsesHoursMinutesSeconds() {
        let stdout = "Elapsed time:  1h2m3s"
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.elapsedSeconds, 3723.0, accuracy: 0.001)
    }

    func testParsesErrors() {
        let stdout = "Errors:                 2"
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.errors, 2)
    }

    func testParsesErrorMessages() {
        let stderr = "ERROR : file.md: Failed to copy"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertEqual(result.errorMessages.count, 1)
        XCTAssertTrue(result.errorMessages[0].contains("Failed to copy"))
    }

    /// The failure that started this: bisync reports fatal errors at NOTICE, so
    /// matching only on "ERROR" missed every one of them.
    func testParsesNoticeLevelBisyncFailure() {
        // swiftlint:disable:next line_length
        let stderr = "2026/08/17 17:52:53 NOTICE: Failed to bisync: prior lock file found: /Users/eric/Library/Caches/rclone/bisync/notes.lck"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertEqual(result.errorMessages.count, 1)
        XCTAssertTrue(result.errorMessages[0].hasPrefix("Failed to bisync: prior lock file found"))
    }

    func testParsesNoticeLevelBisyncAbort() {
        let stderr = "2026/08/17 17:52:53 NOTICE: Bisync aborted. Must run --resync to recover."
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertEqual(result.errorMessages, ["Bisync aborted. Must run --resync to recover."])
    }

    func testParsesCriticalLevel() {
        let stderr = "2026/08/17 17:52:53 CRITICAL: could not create directory"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertEqual(result.errorMessages, ["could not create directory"])
    }

    /// rclone opens every run with this line, and it used to be what the popover
    /// showed in red as the reason a sync failed.
    func testIgnoresRoutineInfoLines() {
        let stderr = """
        2026/08/17 17:57:53 INFO  : Setting --ignore-listing-checksum as neither \
        --checksum nor --compare checksum are set.
        2026/08/17 17:57:53 INFO  : Bisyncing with Comparison Settings:
        2026/08/17 17:57:53 NOTICE: Local file system at /vault: Waiting for checks to finish
        """
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertTrue(result.errorMessages.isEmpty)
    }

    func testErrorMessageDropsTimestampAndLevel() {
        let stderr = "2026/08/17 17:52:53 ERROR : notes/file.md: Failed to copy: permission denied"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertEqual(result.errorMessages, ["notes/file.md: Failed to copy: permission denied"])
    }

    func testEmptyOutput() {
        let result = RcloneOutputParser.parse(stdout: "", stderr: "")

        XCTAssertEqual(result.filesTransferred, 0)
        XCTAssertEqual(result.filesChecked, 0)
        XCTAssertEqual(result.elapsedSeconds, 0)
        XCTAssertEqual(result.errors, 0)
        XCTAssertTrue(result.errorMessages.isEmpty)
    }

    func testNeedsResyncDetected() {
        // Real rclone output includes timestamp prefix
        // swiftlint:disable:next line_length
        let stderr = "2026/03/17 09:08:52 ERROR : Bisync critical error: cannot find prior Path1 or Path2 listings, likely due to critical error on prior run"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertTrue(result.needsResync)
        XCTAssertEqual(result.errorMessages.count, 1)
    }

    func testNeedsResyncDetectedWithoutTimestamp() {
        // swiftlint:disable:next line_length
        let stderr = "ERROR : Bisync critical error: cannot find prior Path1 or Path2 listings, likely due to critical error on prior run"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertTrue(result.needsResync)
    }

    func testNeedsResyncFalseForOtherErrors() {
        let stderr = "ERROR : bisync aborted"
        let result = RcloneOutputParser.parse(stdout: "", stderr: stderr)

        XCTAssertFalse(result.needsResync)
    }

    func testFullVerboseOutput() {
        let stdout = """
        2024/01/15 10:30:00 INFO  : Bisync is running
        Transferred:      512 Bytes / 512 Bytes, 100%, 0 Bytes/s, ETA -
        Checks:                10 / 10, 100%
        Transferred:            1 / 1, 100%
        Elapsed time:        0.8s
        """
        let result = RcloneOutputParser.parse(stdout: stdout, stderr: "")

        XCTAssertEqual(result.filesTransferred, 1)
        XCTAssertEqual(result.filesChecked, 10)
        XCTAssertEqual(result.elapsedSeconds, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.errors, 0)
    }
}
