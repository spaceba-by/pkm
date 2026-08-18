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

        // Installed before run() so a child that exits immediately cannot have
        // its termination missed.
        let exit = ProcessExitWaiter()
        process.terminationHandler = { _ in exit.signal() }

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

        // Both pipes must drain concurrently: if we read stdout to EOF first, a
        // child that fills the stderr pipe buffer blocks forever on write and
        // never closes stdout.
        async let stdoutText = Self.drainInBackground(stdoutPipe.fileHandleForReading, onLine: sink)
        async let stderrText = Self.drainInBackground(stderrPipe.fileHandleForReading, onLine: sink)

        let stdout = await stdoutText
        let stderr = await stderrText

        // Not waitUntilExit(): that spins a CFRunLoop on whatever thread calls
        // it, and a libdispatch worker thread has no run loop servicing the
        // termination source, so it can block forever. Reproduced by looping a
        // trivial child -- it hung within ~10-25 iterations; with the
        // terminationHandler below, 2000 iterations run clean.
        await exit.wait()

        return ProcessOutput(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    private static func drainInBackground(
        _ handle: FileHandle,
        onLine: (@Sendable (String) -> Void)?
    ) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: drain(handle, onLine: onLine))
            }
        }
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
