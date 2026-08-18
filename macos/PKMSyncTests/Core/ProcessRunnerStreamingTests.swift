@testable import PKMSync
import XCTest

/// Exercises the real `ProcessRunner` against `/bin/sh`, since the point of the
/// change is that output arrives *before* the process exits.
final class ProcessRunnerStreamingTests: XCTestCase {
    private let sut = ProcessRunner()

    func testStreamsLinesAsTheyArrive() async throws {
        let collected = LineCollector()

        let output = try await sut.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo one; echo two; echo three"],
            environment: nil,
            onOutputLine: { collected.append($0) }
        )

        XCTAssertEqual(collected.lines, ["one", "two", "three"])
        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.stdout, "one\ntwo\nthree\n")
    }

    /// Regression: `waitUntilExit()` spun a `CFRunLoop` on a libdispatch worker
    /// thread and could block forever. A single run reproduced it only ~5% of
    /// the time, which is what made it read as a flaky test rather than a real
    /// hang; repeating tightens that to near-certain.
    func testRepeatedRunsDoNotHang() async throws {
        for iteration in 1 ... 60 {
            let output = try await sut.run(
                executablePath: "/bin/sh",
                arguments: ["-c", "printf 'tick'"],
                environment: nil,
                onOutputLine: { _ in }
            )
            XCTAssertEqual(output.exitCode, 0, "iteration \(iteration)")
            XCTAssertEqual(output.stdout, "tick", "iteration \(iteration)")
        }
    }

    func testStreamsStderrAsWell() async throws {
        let collected = LineCollector()

        _ = try await sut.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo to-err 1>&2"],
            environment: nil,
            onOutputLine: { collected.append($0) }
        )

        XCTAssertEqual(collected.lines, ["to-err"])
    }

    func testEmitsFinalLineWithoutTrailingNewline() async throws {
        let collected = LineCollector()

        _ = try await sut.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "printf 'no-newline'"],
            environment: nil,
            onOutputLine: { collected.append($0) }
        )

        XCTAssertEqual(collected.lines, ["no-newline"])
    }

    func testDeliversLinesBeforeProcessExits() async throws {
        let collected = LineCollector()
        let sawFirstLineEarly = expectation(description: "first line observed before exit")

        collected.onAppend = { line in
            if line == "first" { sawFirstLineEarly.fulfill() }
        }

        // Copied out of `self` so the concurrent task captures only Sendable values.
        let runner = sut
        let run = Task {
            try await runner.run(
                executablePath: "/bin/sh",
                // Holds the process open after printing, so fulfilment can only
                // happen if output is streamed rather than buffered until exit.
                arguments: ["-c", "echo first; sleep 2; echo second"],
                environment: nil,
                onOutputLine: { collected.append($0) }
            )
        }

        await fulfillment(of: [sawFirstLineEarly], timeout: 1.5)

        let output = try await run.value
        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(collected.lines, ["first", "second"])
    }

    func testConcurrentRunsDoNotStarveTheThreadPool() async {
        // Every `run` needs both of its pipes drained at once, and each drain
        // blocks its thread until the child closes that pipe. While those reads
        // lived on Swift's cooperative pool -- which is sized to the core count
        // -- enough concurrent calls could park every thread, leaving nothing to
        // start the remaining drains. Children then blocked writing to pipes
        // nobody was reading and the run wedged. That is what hung CI.
        let count = 32
        let finished = expectation(description: "all concurrent runs completed")
        finished.expectedFulfillmentCount = count

        // Collected rather than asserted inside the tasks, so that a failing run
        // still reaches `fulfill()` below instead of hanging the test on the
        // other 31. Reuses LineCollector purely as a thread-safe string sink.
        let failures = LineCollector()

        let runner = sut
        for index in 0 ..< count {
            Task {
                do {
                    // Well past the 64KB pipe buffer on both streams, so each
                    // child can only exit if both of its pipes are drained
                    // concurrently -- and only if we read every byte.
                    let output = try await runner.run(
                        executablePath: "/bin/sh",
                        arguments: ["-c", "seq 1 20000; seq 1 20000 1>&2"],
                        environment: nil
                    )
                    if output.exitCode != 0 {
                        failures.append("run \(index) exited \(output.exitCode)")
                    }
                    if !output.stdout.hasSuffix("20000\n") {
                        failures.append("run \(index) truncated stdout")
                    }
                    if !output.stderr.hasSuffix("20000\n") {
                        failures.append("run \(index) truncated stderr")
                    }
                } catch {
                    failures.append("run \(index) threw \(error)")
                }
                finished.fulfill()
            }
        }

        await fulfillment(of: [finished], timeout: 60)
        XCTAssertEqual(failures.lines, [])
    }

    func testStillCapturesLargeOutputWithoutAHandler() async throws {
        // Guards the original deadlock fix: output larger than the pipe buffer.
        let output = try await sut.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "for i in $(seq 1 20000); do echo line-$i; done"],
            environment: nil
        )

        XCTAssertEqual(output.exitCode, 0)
        XCTAssertTrue(output.stdout.hasSuffix("line-20000\n"))
    }

    func testHandlesLinesSplitAcrossReadChunks() async throws {
        let collected = LineCollector()

        _ = try await sut.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "for i in $(seq 1 5000); do echo line-$i; done"],
            environment: nil,
            onOutputLine: { collected.append($0) }
        )

        let lines = collected.lines
        XCTAssertEqual(lines.count, 5000)
        XCTAssertEqual(lines.first, "line-1")
        XCTAssertEqual(lines.last, "line-5000")
    }
}

/// `ProcessRunner` delivers lines on background threads, serialized.
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    private var callback: (@Sendable (String) -> Void)?

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var onAppend: (@Sendable (String) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return callback
        }
        set {
            lock.lock()
            callback = newValue
            lock.unlock()
        }
    }

    func append(_ line: String) {
        lock.lock()
        storage.append(line)
        let callback = callback
        lock.unlock()
        callback?(line)
    }
}
