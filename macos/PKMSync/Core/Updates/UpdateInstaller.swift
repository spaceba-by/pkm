import AppKit
import Foundation

enum UpdateInstaller {
    static func install(zipAt zipURL: URL) async throws {
        let currentAppURL = Bundle.main.bundleURL

        // Verify we have write access
        let appDirectory = currentAppURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: appDirectory.path) else {
            throw UpdateError.noWriteAccess
        }

        // Unzip to temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pkmsync-install-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-xk", zipURL.path, tempDir.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw UpdateError.installFailed("Failed to unzip archive (exit code \(unzip.terminationStatus))")
        }

        // Find the .app bundle in unzipped contents
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )
        guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appNotFoundInArchive
        }

        // Nothing on disk changes until the download has proven it is ours
        try UpdateSignatureVerifier.verify(appAt: newApp)

        // Create backup of current app
        let backupURL = appDirectory.appendingPathComponent(
            currentAppURL.deletingPathExtension().lastPathComponent + ".backup.app"
        )
        try? FileManager.default.removeItem(at: backupURL)
        try replaceApp(at: currentAppURL, with: newApp, backupURL: backupURL)

        // Store backup path for cleanup on next launch
        UserDefaults.standard.set(backupURL.path, forKey: "pkmsync.pendingBackupCleanup")

        // Clean up the download
        try? FileManager.default.removeItem(at: zipURL)

        // Relaunch
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        relaunch.arguments = [currentAppURL.path]
        try relaunch.run()

        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Moves the current app to `backupURL` and the new app into its place, restoring the backup on failure.
    static func replaceApp(
        at currentAppURL: URL,
        with newAppURL: URL,
        backupURL: URL,
        move: (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }
    ) throws {
        try move(currentAppURL, backupURL)

        do {
            try move(newAppURL, currentAppURL)
        } catch {
            let installError = error.localizedDescription
            do {
                try move(backupURL, currentAppURL)
            } catch {
                // The app is no longer at its install path, so the user has to know where it went.
                throw UpdateError.rollbackFailed(
                    installError: installError,
                    rollbackError: error.localizedDescription,
                    backupPath: backupURL.path
                )
            }
            throw UpdateError.installFailed("Failed to replace app: \(installError)")
        }
    }

    static func cleanupPendingBackup() {
        guard let backupPath = UserDefaults.standard.string(forKey: "pkmsync.pendingBackupCleanup") else {
            return
        }
        try? FileManager.default.removeItem(atPath: backupPath)
        UserDefaults.standard.removeObject(forKey: "pkmsync.pendingBackupCleanup")
    }
}
