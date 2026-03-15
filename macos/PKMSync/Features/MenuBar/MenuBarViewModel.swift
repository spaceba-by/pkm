import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class MenuBarViewModel {
    let configuration: SyncConfiguration
    let scheduler: SyncScheduler
    private let conflictService: ConflictServiceProtocol

    private(set) var conflicts: [ConflictFile] = []
    private(set) var recentFiles: [RecentFile] = []

    init(
        configuration: SyncConfiguration = SyncConfiguration(),
        scheduler: SyncScheduler? = nil,
        conflictService: ConflictServiceProtocol = ConflictService()
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
    }

    var status: SyncStatus {
        scheduler.status
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

    func startScheduler() {
        guard configuration.isConfigured else { return }
        scheduler.start()
    }

    func stopScheduler() {
        scheduler.stop()
    }

    func syncNow() async {
        await scheduler.syncNow()
        await refreshConflicts()
        await refreshRecentFiles()
    }

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

    private(set) var lastError: String?

    func resolveConflict(_ conflict: ConflictFile, resolution: ConflictResolution) {
        do {
            try conflictService.resolveConflict(conflict, resolution: resolution)
            conflicts.removeAll { $0.id == conflict.id }
            lastError = nil
        } catch {
            lastError = "Failed to resolve conflict: \(error.localizedDescription)"
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
