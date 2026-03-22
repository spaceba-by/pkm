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

        // Create backup of current app
        let backupURL = appDirectory.appendingPathComponent(
            currentAppURL.deletingPathExtension().lastPathComponent + ".backup.app"
        )
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.moveItem(at: currentAppURL, to: backupURL)

        // Move new app to current location
        do {
            try FileManager.default.moveItem(at: newApp, to: currentAppURL)
        } catch {
            // Rollback: restore backup
            try? FileManager.default.moveItem(at: backupURL, to: currentAppURL)
            throw UpdateError.installFailed("Failed to replace app: \(error.localizedDescription)")
        }

        // Store backup path for cleanup on next launch
        UserDefaults.standard.set(backupURL.path, forKey: "pkmsync.pendingBackupCleanup")

        // Clean up temp files
        try? FileManager.default.removeItem(at: tempDir)
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

    static func cleanupPendingBackup() {
        guard let backupPath = UserDefaults.standard.string(forKey: "pkmsync.pendingBackupCleanup") else {
            return
        }
        try? FileManager.default.removeItem(atPath: backupPath)
        UserDefaults.standard.removeObject(forKey: "pkmsync.pendingBackupCleanup")
    }
}
