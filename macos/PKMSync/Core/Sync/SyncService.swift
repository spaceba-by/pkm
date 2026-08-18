import Foundation

struct SyncService: SyncServiceProtocol {
    /// How often rclone prints its stats block. Drives the progress bar and
    /// throughput readout, so it wants to be frequent enough to look live.
    private static let statsInterval = "1s"

    private let configuration: SyncConfiguration
    private let processRunner: ProcessRunnerProtocol

    init(
        configuration: SyncConfiguration,
        processRunner: ProcessRunnerProtocol = ProcessRunner()
    ) {
        self.configuration = configuration
        self.processRunner = processRunner
    }

    func sync(onProgress: (@Sendable (SyncProgress) -> Void)? = nil) async throws -> SyncLogEntry {
        try await runSync(resync: false, onProgress: onProgress)
    }

    func resync(onProgress: (@Sendable (SyncProgress) -> Void)? = nil) async throws -> SyncLogEntry {
        try await runSync(resync: true, onProgress: onProgress)
    }

    private func runSync(
        resync: Bool,
        onProgress: (@Sendable (SyncProgress) -> Void)?
    ) async throws -> SyncLogEntry {
        guard configuration.isConfigured else {
            throw SyncError.notConfigured
        }

        let rclonePath = configuration.resolvedRclonePath()
        guard !rclonePath.isEmpty, FileManager.default.isExecutableFile(atPath: rclonePath) else {
            throw SyncError.rcloneNotFound
        }

        let arguments = buildArguments(resync: resync)
        let startTime = Date()

        let output = try await processRunner.run(
            executablePath: rclonePath,
            arguments: arguments,
            environment: nil,
            onOutputLine: Self.outputLineHandler(reporting: onProgress)
        )

        let elapsed = Date().timeIntervalSince(startTime)
        let parsed = RcloneOutputParser.parse(stdout: output.stdout, stderr: output.stderr)

        if output.exitCode != 0 {
            if !resync, parsed.needsResync {
                return try await runSync(resync: true, onProgress: onProgress)
            }

            return SyncLogEntry(
                timestamp: startTime,
                filesTransferred: parsed.filesTransferred,
                filesChecked: parsed.filesChecked,
                success: false,
                errorMessage: parsed.errorMessages.first ?? Self.exitCodeMessage(for: output),
                rawOutput: Self.combinedOutput(of: output),
                duration: elapsed
            )
        }

        return SyncLogEntry(
            timestamp: startTime,
            filesTransferred: parsed.filesTransferred,
            filesChecked: parsed.filesChecked,
            success: true,
            rawOutput: Self.combinedOutput(of: output),
            duration: elapsed
        )
    }

    /// Wires a fresh parser to `onProgress`, or returns `nil` so the runner can
    /// skip line-by-line delivery when nobody is listening.
    private static func outputLineHandler(
        reporting onProgress: (@Sendable (SyncProgress) -> Void)?
    ) -> (@Sendable (String) -> Void)? {
        onProgress.map { report in
            let parser = RcloneProgressParser()
            return { line in
                if let progress = parser.consume(line: line) {
                    report(progress)
                }
            }
        }
    }

    /// Used when rclone fails without a line the parser recognises as the cause.
    ///
    /// Quoting the head of stderr instead — as this once did — surfaced rclone's
    /// opening "Setting --ignore-listing-checksum ..." INFO line as the error for
    /// every single failure. The full output stays one click away in `rawOutput`.
    private static func exitCodeMessage(for output: ProcessOutput) -> String {
        "rclone exited with code \(output.exitCode)"
    }

    private static func combinedOutput(of output: ProcessOutput) -> String? {
        let combined = [
            output.stdout.isEmpty ? nil : "--- STDOUT ---\n\(output.stdout)",
            output.stderr.isEmpty ? nil : "--- STDERR ---\n\(output.stderr)",
        ]
        .compactMap(\.self)
        .joined(separator: "\n")

        return combined.isEmpty ? nil : combined
    }

    private func buildArguments(resync: Bool) -> [String] {
        var args = [
            "bisync",
            configuration.vaultPath,
            "pkm-s3:\(configuration.bucketName)",
            "--conflict-resolve", "newer",
            "--verbose",
            // Periodic stats are what make a long transfer observable.
            "--stats", Self.statsInterval,
            // rclone colours its output even when writing to a pipe, which would
            // otherwise land as escape codes in the log and in parsed messages.
            "--color", "NEVER",
        ]

        if resync {
            args.append("--resync")
        } else {
            args += ["--recover", "--resilient", "--max-lock", "2m"]
        }

        if !configuration.filterFilePath.isEmpty {
            args += ["--filter-from", configuration.filterFilePath]
        }

        return args
    }
}
