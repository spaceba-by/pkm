import Foundation
import Observation

@Observable
final class SyncConfiguration: @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefix = "pkmsync."

    var vaultPath: String {
        get { defaults.string(forKey: prefix + "vaultPath") ?? "" }
        set { defaults.set(newValue, forKey: prefix + "vaultPath") }
    }

    var bucketName: String {
        get { defaults.string(forKey: prefix + "bucketName") ?? "" }
        set { defaults.set(newValue, forKey: prefix + "bucketName") }
    }

    var syncIntervalMinutes: Int {
        get {
            let value = defaults.integer(forKey: prefix + "syncIntervalMinutes")
            return value > 0 ? value : 5
        }
        set { defaults.set(newValue, forKey: prefix + "syncIntervalMinutes") }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: prefix + "launchAtLogin") }
        set { defaults.set(newValue, forKey: prefix + "launchAtLogin") }
    }

    var rclonePath: String {
        get { defaults.string(forKey: prefix + "rclonePath") ?? "" }
        set { defaults.set(newValue, forKey: prefix + "rclonePath") }
    }

    var filterFilePath: String {
        get { defaults.string(forKey: prefix + "filterFilePath") ?? "" }
        set { defaults.set(newValue, forKey: prefix + "filterFilePath") }
    }

    var maxLogEntries: Int {
        get {
            let value = defaults.integer(forKey: prefix + "maxLogEntries")
            return value > 0 ? value : 50
        }
        set { defaults.set(newValue, forKey: prefix + "maxLogEntries") }
    }

    var isConfigured: Bool {
        !vaultPath.isEmpty && !bucketName.isEmpty
    }

    var syncIntervalSeconds: TimeInterval {
        TimeInterval(syncIntervalMinutes * 60)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func resolvedRclonePath() -> String {
        if !rclonePath.isEmpty {
            return rclonePath
        }
        let candidates = [
            "/opt/homebrew/bin/rclone",
            "/usr/local/bin/rclone",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        // Fall back to which(1) to find rclone on PATH
        if let whichPath = resolveViaWhich("rclone") {
            return whichPath
        }
        return ""
    }

    private func resolveViaWhich(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }
}
