import Foundation

struct SyncService: SyncServiceProtocol {
    private let configuration: SyncConfiguration
    private let processRunner: ProcessRunnerProtocol

    init(
        configuration: SyncConfiguration,
        processRunner: ProcessRunnerProtocol = ProcessRunner()
    ) {
        self.configuration = configuration
        self.processRunner = processRunner
    }

    func sync() async throws -> SyncLogEntry {
        try await runSync(resync: false)
    }

    func resync() async throws -> SyncLogEntry {
        try await runSync(resync: true)
    }

    private func runSync(resync: Bool) async throws -> SyncLogEntry {
        guard configuration.isConfigured else {
            throw SyncError.notConfigured
        }

        let rclonePath = configuration.resolvedRclonePath()
        guard FileManager.default.isExecutableFile(atPath: rclonePath) else {
            throw SyncError.rcloneNotFound
        }

        let arguments = buildArguments(resync: resync)
        let startTime = Date()

        let output = try await processRunner.run(
            executablePath: rclonePath,
            arguments: arguments,
            environment: nil
        )

        let elapsed = Date().timeIntervalSince(startTime)
        let parsed = RcloneOutputParser.parse(stdout: output.stdout, stderr: output.stderr)

        if output.exitCode != 0 {
            let errorMessage = parsed.errorMessages.first ?? output.stderr.prefix(200).description
            return SyncLogEntry(
                timestamp: startTime,
                filesTransferred: parsed.filesTransferred,
                filesChecked: parsed.filesChecked,
                success: false,
                errorMessage: errorMessage,
                duration: elapsed
            )
        }

        return SyncLogEntry(
            timestamp: startTime,
            filesTransferred: parsed.filesTransferred,
            filesChecked: parsed.filesChecked,
            success: true,
            duration: elapsed
        )
    }

    private func buildArguments(resync: Bool) -> [String] {
        var args = [
            "bisync",
            configuration.vaultPath,
            "pkm-s3:\(configuration.bucketName)",
            "--conflict-resolve", "newer",
            "--verbose",
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
