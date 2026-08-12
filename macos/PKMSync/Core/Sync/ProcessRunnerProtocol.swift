import Foundation

struct ProcessOutput: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol ProcessRunnerProtocol: Sendable {
    /// Runs `executablePath` to completion.
    ///
    /// - Parameter onOutputLine: Called with each complete line of stdout and
    ///   stderr as it arrives, so callers can report progress before the process
    ///   exits. Calls are serialized and ordered within each stream, but arrive
    ///   on an arbitrary thread.
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        onOutputLine: (@Sendable (String) -> Void)?
    ) async throws -> ProcessOutput
}

extension ProcessRunnerProtocol {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput {
        try await run(
            executablePath: executablePath,
            arguments: arguments,
            environment: environment,
            onOutputLine: nil
        )
    }
}
