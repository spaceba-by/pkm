import Foundation

struct ProcessRunner: ProcessRunnerProtocol {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read pipes on background threads to avoid deadlock when the OS
        // pipe buffer fills before the process terminates.
        async let stdoutData = Task.detached {
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let stderrData = Task.detached {
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }.value

        let stdout = await stdoutData
        let stderr = await stderrData

        process.waitUntilExit()

        return ProcessOutput(
            stdout: String(data: stdout, encoding: .utf8) ?? "",
            stderr: String(data: stderr, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}
