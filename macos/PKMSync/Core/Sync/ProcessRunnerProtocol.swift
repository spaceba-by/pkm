import Foundation

struct ProcessOutput: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol ProcessRunnerProtocol: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput
}
