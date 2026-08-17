import Foundation

struct ProcessRunner: ProcessRunnerProtocol {
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        onOutputLine: (@Sendable (String) -> Void)?
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

        // stdout and stderr drain on separate threads, so serialize delivery:
        // RcloneProgressParser is a state machine and must not see two lines at once.
        let sink: (@Sendable (String) -> Void)?
        if let onOutputLine {
            let lock = NSLock()
            sink = { line in
                lock.lock()
                defer { lock.unlock() }
                onOutputLine(line)
            }
        } else {
            sink = nil
        }

        // Read pipes on background threads to avoid deadlock when the OS
        // pipe buffer fills before the process terminates.
        async let stdoutText = Task.detached {
            Self.drain(stdoutPipe.fileHandleForReading, onLine: sink)
        }.value
        async let stderrText = Task.detached {
            Self.drain(stderrPipe.fileHandleForReading, onLine: sink)
        }.value

        let stdout = await stdoutText
        let stderr = await stderrText

        process.waitUntilExit()

        return ProcessOutput(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// Reads `handle` to EOF, emitting each complete line to `onLine` as it
    /// arrives rather than only at exit.
    private static func drain(
        _ handle: FileHandle,
        onLine: (@Sendable (String) -> Void)?
    ) -> String {
        var all = Data()
        var pending = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            all.append(chunk)

            guard let onLine else { continue }

            pending.append(chunk)
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                let line = Data(pending[pending.startIndex ..< newline])
                pending = Data(pending[pending.index(after: newline)...])
                if let text = String(data: line, encoding: .utf8) {
                    onLine(text)
                }
            }
        }

        // A final line without a trailing newline.
        if let onLine, !pending.isEmpty, let text = String(data: pending, encoding: .utf8) {
            onLine(text)
        }

        return String(data: all, encoding: .utf8) ?? ""
    }
}
