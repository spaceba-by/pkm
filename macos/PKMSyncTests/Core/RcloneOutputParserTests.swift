import XCTest

@testable import PKMSync

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

    func testEmptyOutput() {
        let result = RcloneOutputParser.parse(stdout: "", stderr: "")

        XCTAssertEqual(result.filesTransferred, 0)
        XCTAssertEqual(result.filesChecked, 0)
        XCTAssertEqual(result.elapsedSeconds, 0)
        XCTAssertEqual(result.errors, 0)
        XCTAssertTrue(result.errorMessages.isEmpty)
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
