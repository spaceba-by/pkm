import Foundation
@testable import PKMSync

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    var result: Result<ProcessOutput, Error> = .success(
        ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    )
    var results: [Result<ProcessOutput, Error>] = []
    /// Lines handed to `onOutputLine` before returning, simulating streamed output.
    var streamedLines: [String] = []
    private(set) var runCallCount = 0
    private(set) var lastArguments: [String] = []
    private(set) var allArguments: [[String]] = []
    private(set) var lastExecutablePath: String = ""
    private(set) var receivedOutputHandler = false

    func run(
        executablePath: String,
        arguments: [String],
        environment _: [String: String]?,
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> ProcessOutput {
        runCallCount += 1
        lastExecutablePath = executablePath
        lastArguments = arguments
        allArguments.append(arguments)
        receivedOutputHandler = onOutputLine != nil

        if let onOutputLine {
            for line in streamedLines {
                onOutputLine(line)
            }
        }

        if !results.isEmpty {
            return try results.removeFirst().get()
        }
        return try result.get()
    }
}
