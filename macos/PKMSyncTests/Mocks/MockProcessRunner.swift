import Foundation

@testable import PKMSync

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    var result: Result<ProcessOutput, Error> = .success(
        ProcessOutput(stdout: "", stderr: "", exitCode: 0)
    )
    private(set) var runCallCount = 0
    private(set) var lastArguments: [String] = []
    private(set) var lastExecutablePath: String = ""

    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput {
        runCallCount += 1
        lastExecutablePath = executablePath
        lastArguments = arguments
        return try result.get()
    }
}
