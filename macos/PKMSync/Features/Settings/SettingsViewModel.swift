import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    var configuration: SyncConfiguration

    var rcloneStatus: String = ""
    private(set) var isResyncing = false
    private(set) var resyncMessage: String?
    private(set) var isCheckingForUpdates = false
    private(set) var updateCheckMessage: String?

    private let updateService: UpdateServiceProtocol

    static let intervalOptions = [1, 2, 5, 10, 15, 30]
    static let updateIntervalOptions = [1, 4, 12, 24]

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    init(
        configuration: SyncConfiguration = SyncConfiguration(),
        updateService: UpdateServiceProtocol = GitHubUpdateService()
    ) {
        self.configuration = configuration
        self.updateService = updateService
        syncLaunchAtLoginState()
        checkRclone()
    }

    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        configuration.launchAtLogin = (status == .enabled)
    }

    func checkRclone() {
        let path = configuration.resolvedRclonePath()
        if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            rcloneStatus = "Found at \(path)"
        } else {
            rcloneStatus = "Not found — install with: brew install rclone"
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

    func forceResync() async {
        guard configuration.isConfigured else {
            resyncMessage = "Configure vault path and bucket name first."
            return
        }

        isResyncing = true
        resyncMessage = nil

        let syncService = SyncService(configuration: configuration)
        do {
            let entry = try await syncService.resync()
            if entry.success {
                resyncMessage = "Resync completed successfully."
            } else {
                resyncMessage = entry.errorMessage ?? "Resync failed."
            }
        } catch {
            resyncMessage = "Resync failed: \(error.localizedDescription)"
        }

        isResyncing = false
    }

    func checkForUpdates() async {
        isCheckingForUpdates = true
        updateCheckMessage = nil

        let service = updateService
        let version = currentVersion
        do {
            let update = try await Task.detached {
                try await service.checkForUpdate(currentVersion: version)
            }.value
            if let update {
                updateCheckMessage = "Update available: v\(update.version)"
            } else {
                updateCheckMessage = "You're up to date."
            }
        } catch {
            updateCheckMessage = "Check failed: \(error.localizedDescription)"
        }

        isCheckingForUpdates = false
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
