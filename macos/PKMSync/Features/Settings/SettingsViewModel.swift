import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    var configuration: SyncConfiguration

    var rcloneStatus: String = ""

    static let intervalOptions = [1, 2, 5, 10, 15, 30]

    init(configuration: SyncConfiguration = SyncConfiguration()) {
        self.configuration = configuration
        checkRclone()
    }

    func checkRclone() {
        let path = configuration.resolvedRclonePath()
        if FileManager.default.isExecutableFile(atPath: path) {
            rcloneStatus = "Found at \(path)"
        } else {
            rcloneStatus = "Not found"
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        configuration.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            configuration.launchAtLogin = !enabled
        }
    }

    func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"

        if panel.runModal() == .OK, let url = panel.url {
            configuration.vaultPath = url.path
        }
    }

    func selectFilterFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "Select rclone filter file"

        if panel.runModal() == .OK, let url = panel.url {
            configuration.filterFilePath = url.path
        }
    }
}
