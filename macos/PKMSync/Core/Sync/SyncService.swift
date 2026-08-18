import Foundation

/// Drives the two-phase vault sync.
///
/// Phase 1 is a `bisync` of human-authored notes with `_agent/` filtered out.
/// Phase 2 pulls `_agent/` one-way from S3, which makes the remote
/// unconditionally authoritative for agent output: a local edit under `_agent/`
/// is overwritten on the next pull and never reaches S3.
///
/// Keeping `_agent/` out of bisync also removes it from bisync's listing
/// comparison, so Lambda writing to `_agent/` mid-run cannot destabilise the
/// bisync state, and agent output can never produce a `.conflict` file.
struct SyncService: SyncServiceProtocol {
    /// How often rclone prints its stats block. Drives the progress bar and
    /// throughput readout, so it wants to be frequent enough to look live.
    private static let statsInterval = "1s"

    /// Agent artifacts that should never land in an Obsidian vault:
    /// `search/vector-index.json` is a monolithic embeddings blob rewritten in
    /// full on every index run, and `dispatch/` holds unbounded ECS job
    /// artifacts including code trees.
    private static let agentPullExcludes = [
        "search/vector-index.json",
        "dispatch/**",
    ]

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

        let filterFilePath = configuration.resolvedFilterFilePath()
        try BisyncFilterFile.ensureExists(at: filterFilePath)

        let startTime = Date()
        var bisyncResult = try await runPhase(
            rclonePath: rclonePath,
            arguments: buildBisyncArguments(resync: resync, filterFilePath: filterFilePath),
            onProgress: onProgress
        )

        // bisync loses its listing files after an interrupted run; a --resync
        // rebuilds them. Only retry once, and only when that is the failure.
        if bisyncResult.exitCode != 0, !resync, bisyncResult.parsed.needsResync {
            bisyncResult = try await runPhase(
                rclonePath: rclonePath,
                arguments: buildBisyncArguments(resync: true, filterFilePath: filterFilePath),
                onProgress: onProgress
            )
        }

        // The pull is independent of bisync, so run it even when bisync failed
        // -- agent output is still worth refreshing, and the failure is
        // reported either way.
        var phases = [(name: "bisync", result: bisyncResult)]
        if configuration.agentPullEnabled {
            let pull = try await runPhase(
                rclonePath: rclonePath,
                arguments: buildAgentPullArguments(),
                onProgress: onProgress
            )
            phases.append((name: "_agent pull", result: pull))
        }

        return makeLogEntry(phases: phases, startTime: startTime)
    }

    private func runPhase(
        rclonePath: String,
        arguments: [String],
        onProgress: (@Sendable (SyncProgress) -> Void)?
    ) async throws -> PhaseResult {
        let output = try await processRunner.run(
            executablePath: rclonePath,
            arguments: arguments,
            environment: nil,
            onOutputLine: Self.outputLineHandler(reporting: onProgress)
        )
        return PhaseResult(
            output: output,
            parsed: RcloneOutputParser.parse(stdout: output.stdout, stderr: output.stderr)
        )
    }

    /// Folds every phase into the single entry the log and menu bar show.
    ///
    /// Counts are summed so the user sees total work done, and the first
    /// failing phase names itself in the error so "which half broke?" is
    /// answerable without opening the raw output.
    private func makeLogEntry(
        phases: [(name: String, result: PhaseResult)],
        startTime: Date
    ) -> SyncLogEntry {
        let elapsed = Date().timeIntervalSince(startTime)
        let failed = phases.filter { $0.result.exitCode != 0 }

        let errorMessage = failed.first.map { phase in
            let detail = phase.result.parsed.errorMessages.first
                ?? Self.exitCodeMessage(for: phase.result.output)
            return "\(phase.name): \(detail)"
        }

        let rawOutput = phases
            .compactMap { Self.combinedOutput(of: $0.result.output, phase: $0.name) }
            .joined(separator: "\n")

        return SyncLogEntry(
            timestamp: startTime,
            filesTransferred: phases.reduce(0) { $0 + $1.result.parsed.filesTransferred },
            filesChecked: phases.reduce(0) { $0 + $1.result.parsed.filesChecked },
            success: failed.isEmpty,
            errorMessage: errorMessage,
            rawOutput: rawOutput.isEmpty ? nil : rawOutput,
            duration: elapsed
        )
    }

    /// Wires a fresh parser to `onProgress`, or returns `nil` so the runner can
    /// skip line-by-line delivery when nobody is listening.
    ///
    /// Each phase gets its own parser, so the pull's stats do not inherit the
    /// bisync's totals.
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

    private static func combinedOutput(of output: ProcessOutput, phase: String) -> String? {
        let combined = [
            output.stdout.isEmpty ? nil : "--- \(phase) STDOUT ---\n\(output.stdout)",
            output.stderr.isEmpty ? nil : "--- \(phase) STDERR ---\n\(output.stderr)",
        ]
        .compactMap(\.self)
        .joined(separator: "\n")

        return combined.isEmpty ? nil : combined
    }

    private func buildBisyncArguments(resync: Bool, filterFilePath: String) -> [String] {
        var args = [
            "bisync",
            configuration.vaultPath,
            "pkm-s3:\(configuration.bucketName)",
            "--conflict-resolve", "newer",
            "--conflict-loser", "rename",
            // --filters-file, not --filter-from: only the former MD5-hashes the
            // file and aborts demanding a --resync when it changes. Without that
            // guard, newly excluded files look deleted to bisync and get deleted
            // for real on both sides.
            "--filters-file", filterFilePath,
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

        return args
    }

    private func buildAgentPullArguments() -> [String] {
        var args = [
            "copy",
            "pkm-s3:\(configuration.bucketName)/_agent",
            "\(configuration.vaultPath)/_agent",
            // Agent objects are written by Lambda and carry no rclone mtime
            // metadata, so reading their modtime costs a HEAD per object.
            // The S3 LastModified is the right answer here anyway.
            "--use-server-modtime",
        ]

        for pattern in Self.agentPullExcludes {
            args += ["--exclude", pattern]
        }

        args += [
            "--verbose",
            "--stats", Self.statsInterval,
            "--color", "NEVER",
        ]
        return args
    }

    private struct PhaseResult {
        let output: ProcessOutput
        let parsed: RcloneParseResult

        var exitCode: Int32 {
            output.exitCode
        }
    }
}
