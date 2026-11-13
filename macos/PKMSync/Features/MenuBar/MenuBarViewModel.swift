import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MenuBarViewModel {
    let configuration: SyncConfiguration
    let scheduler: SyncScheduler
    private let conflictService: ConflictServiceProtocol
    private let updateService: UpdateServiceProtocol
    private let installUpdate: @Sendable (URL) async throws -> Void

    private(set) var conflicts: [ConflictFile] = []
    private(set) var recentFiles: [RecentFile] = []
    private(set) var lastError: String?
    private(set) var updateState: UpdateState = .idle
    private(set) var availableUpdate: AppUpdate?
    private var downloadedZipURL: URL?
    private var updateCheckTask: Task<Void, Never>?
    private var lastUpdateCheck: Date?
    private var isInstalling = false

    private let detailWindowController = WindowController()
    private let diffWindowController = WindowController()
    private let logWindowController = WindowController()

    private(set) var selectedConflict: ConflictFile?

    init(
        configuration: SyncConfiguration = SyncConfiguration(),
        scheduler: SyncScheduler? = nil,
        conflictService: ConflictServiceProtocol = ConflictService(),
        updateService: UpdateServiceProtocol = GitHubUpdateService(),
        installUpdate: @escaping @Sendable (URL) async throws -> Void = { try await UpdateInstaller.install(zipAt: $0) }
    ) {
        self.configuration = configuration
        if let scheduler {
            self.scheduler = scheduler
        } else {
            let syncService = SyncService(configuration: configuration)
            self.scheduler = SyncScheduler(
                syncService: syncService,
                configuration: configuration
            )
        }
        self.conflictService = conflictService
        self.updateService = updateService
        self.installUpdate = installUpdate
    }

    // MARK: - Sync State

    var status: SyncStatus {
        scheduler.status
    }

    /// Whether rclone is still working. `status` alone cannot answer this: a run
    /// that fails leaves `.error` behind while an earlier, longer run carries on.
    var isSyncInFlight: Bool {
        scheduler.isSyncInFlight
    }

    var recentLogs: [SyncLogEntry] {
        scheduler.recentLogs
    }

    var lastSyncDate: Date? {
        scheduler.lastSyncDate
    }

    var hasConflicts: Bool {
        !conflicts.isEmpty
    }

    var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Scheduler

    func startScheduler() {
        guard configuration.isConfigured else { return }
        scheduler.start()
        startUpdateCheckScheduler()
    }

    func stopScheduler() {
        scheduler.stop()
    }

    func syncNow() async {
        await scheduler.syncNow()
        await refreshConflicts()
        await refreshRecentFiles()
    }

    // MARK: - Conflicts & Recent Files

    func refreshConflicts() async {
        guard configuration.isConfigured else { return }
        let vaultPath = configuration.vaultPath
        let service = conflictService
        do {
            let found = try await Task.detached {
                try await service.scanForConflicts(in: vaultPath)
            }.value
            conflicts = found
        } catch {
            conflicts = []
        }
    }

    func refreshRecentFiles() async {
        guard configuration.isConfigured else { return }
        let vaultPath = configuration.vaultPath
        let files = await Task.detached {
            await Self.loadRecentFiles(from: vaultPath)
        }.value
        recentFiles = files
    }

    func resolveConflict(_ conflict: ConflictFile, resolution: ConflictResolution) {
        do {
            try conflictService.resolveConflict(conflict, resolution: resolution)
            conflicts.removeAll { $0.id == conflict.id }
            lastError = nil
        } catch {
            lastError = "Failed to resolve conflict: \(error.localizedDescription)"
        }
    }

    // MARK: - Window Management

    func showDetailWindow() {
        let viewModel = self
        detailWindowController.show(
            title: "Sal Sync — Details",
            size: NSSize(width: 600, height: 500)
        ) {
            DetailView(viewModel: viewModel)
        }
    }

    func showDiff(for conflict: ConflictFile) {
        selectedConflict = conflict

        let diffViewModel = ConflictDetailViewModel(
            conflict: conflict,
            vaultPath: configuration.vaultPath,
            conflictService: conflictService
        )
        diffViewModel.onResolved = { [weak self] in
            self?.conflicts.removeAll { $0.id == conflict.id }
            self?.selectedConflict = nil
        }

        diffWindowController.show(
            title: "Conflict: \(conflict.relativePath(from: configuration.vaultPath))",
            size: NSSize(width: 600, height: 500)
        ) { [weak self] in
            ConflictDetailView(
                viewModel: diffViewModel,
                onDismiss: {
                    self?.diffWindowController.close()
                    self?.selectedConflict = nil
                }
            )
        }
    }

    func showLog(for entry: SyncLogEntry) {
        let output = entry.rawOutput ?? entry.errorMessage ?? "No output available"
        logWindowController.show(
            title: "Sync Log — \(entry.timestamp.formatted(date: .abbreviated, time: .standard))",
            size: NSSize(width: 700, height: 500)
        ) {
            SyncLogDetailView(timestamp: entry.timestamp, output: output)
        }
    }

    // MARK: - Updates

    func startUpdateCheckScheduler() {
        updateCheckTask?.cancel()
        guard configuration.autoCheckForUpdates else { return }

        updateCheckTask = Task { [weak self] in
            // Initial check after a short delay
            try? await Task.sleep(for: .seconds(5))
            await self?.checkForUpdates()

            // Periodic checks
            while !Task.isCancelled {
                guard let self else { return }
                let hours = configuration.updateCheckIntervalHours
                try? await Task.sleep(for: .seconds(hours * 3600))
                guard !Task.isCancelled else { return }
                await checkForUpdates()
            }
        }
    }

    /// A failed rollback leaves the app only at its backup path, and nothing this
    /// process does can undo that. So the recovery row stays until the app is
    /// relaunched, and no check or install may replace it.
    var needsRecovery: Bool {
        if case .recoveryNeeded = updateState { true } else { false }
    }

    func checkForUpdates(force: Bool = false) async {
        // A check would swap the recovery row for a normal result, hiding the backup
        // path; one during an install would show stale state over it
        guard !needsRecovery, !isInstalling else { return }

        // Rate limit: skip if checked within last 5 minutes (unless forced)
        if !force, let last = lastUpdateCheck, Date().timeIntervalSince(last) < 300 {
            return
        }

        setUpdateState(.checking)
        lastUpdateCheck = Date()

        let service = updateService
        let version = currentAppVersion
        do {
            let update = try await Task.detached {
                try await service.checkForUpdate(currentVersion: version)
            }.value
            // The rollback may have failed while this check was in flight
            guard !needsRecovery else { return }
            if let update {
                availableUpdate = update
                setUpdateState(.available(version: update.version))
            } else {
                setUpdateState(.upToDate)
            }
        } catch {
            setUpdateState(.error(message: error.localizedDescription))
        }
    }

    func downloadAndInstall() async {
        // Installing over a failed rollback could lose the only copy of the app
        guard !needsRecovery, !isInstalling, let update = availableUpdate else { return }

        if let zipURL = downloadedZipURL {
            // Already downloaded, proceed to install
            isInstalling = true
            defer { isInstalling = false }
            let install = installUpdate
            do {
                try await Task.detached {
                    try await install(zipURL)
                }.value
            } catch {
                // Retrying must download again, not reinstall a zip that just failed
                downloadedZipURL = nil
                setUpdateState(Self.installFailureState(for: error))
            }
            return
        }

        setUpdateState(.downloading(progress: 0))
        let service = updateService
        do {
            let zipURL = try await Task.detached {
                try await service.downloadUpdate(update) { progress in
                    Task { @MainActor [weak self] in
                        self?.setUpdateState(.downloading(progress: progress))
                    }
                }
            }.value
            downloadedZipURL = zipURL
            setUpdateState(.readyToInstall)
        } catch {
            setUpdateState(.error(message: error.localizedDescription))
        }
    }

    /// Every update-state change goes through here, so recovery state is never replaced.
    private func setUpdateState(_ state: UpdateState) {
        guard !needsRecovery else { return }
        updateState = state
    }

    /// A failed rollback leaves the app only at its backup path, so the row has to keep that path visible.
    static func installFailureState(for error: Error) -> UpdateState {
        if case let UpdateError.rollbackFailed(_, _, backupPath) = error {
            return .recoveryNeeded(message: error.localizedDescription, backupPath: backupPath)
        }
        return .error(message: error.localizedDescription)
    }

    func revealBackup(at path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func viewReleaseNotes() {
        guard let update = availableUpdate else { return }
        let urlString = "https://github.com/spaceba-by/pkm/releases/tag/macos-v\(update.version)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Obsidian

    func openInObsidian(_ file: RecentFile) {
        let vaultName = (configuration.vaultPath as NSString).lastPathComponent
        let filePath = (file.relativePath as NSString).deletingPathExtension

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "file", value: filePath),
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    nonisolated private static func loadRecentFiles(from vaultPath: String) async -> [RecentFile] {
        let vaultURL = URL(fileURLWithPath: vaultPath)
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [RecentFile] = []

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "md" else { continue }
            guard !fileURL.path.contains(".conflict") else { continue }

            let modDate = (try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate) ?? Date.distantPast

            let relativePath = String(fileURL.path.dropFirst(vaultPath.count + 1))
            files.append(RecentFile(
                name: fileURL.deletingPathExtension().lastPathComponent,
                relativePath: relativePath,
                modified: modDate
            ))
        }

        return Array(files
            .sorted { $0.modified > $1.modified }
            .prefix(10))
    }
}

struct RecentFile: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let relativePath: String
    let modified: Date
}
