import Foundation
@testable import PKMSync

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    var result: Result<ProcessOutput, Error> = .success(
        ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    )
    var results: [Result<ProcessOutput, Error>] = []
    private(set) var runCallCount = 0
    private(set) var lastArguments: [String] = []
    private(set) var allArguments: [[String]] = []
    private(set) var lastExecutablePath: String = ""

    func run(
        executablePath: String,
        arguments: [String],
        environment _: [String: String]?
    ) async throws -> ProcessOutput {
        runCallCount += 1
        lastExecutablePath = executablePath
        lastArguments = arguments
        allArguments.append(arguments)

        if !results.isEmpty {
            return try results.removeFirst().get()
        }
        return try result.get()
    }
}
