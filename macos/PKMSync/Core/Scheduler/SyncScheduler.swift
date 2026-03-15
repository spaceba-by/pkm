import Foundation
import Observation

@MainActor
@Observable
final class SyncScheduler: SyncSchedulerProtocol {
    private let syncService: SyncServiceProtocol
    private let configuration: SyncConfiguration

    private(set) var isRunning = false
    private(set) var status: SyncStatus = .idle
    private(set) var recentLogs: [SyncLogEntry] = []
    private(set) var lastSyncDate: Date?

    private var schedulerTask: Task<Void, Never>?

    init(
        syncService: SyncServiceProtocol,
        configuration: SyncConfiguration
    ) {
        self.syncService = syncService
        self.configuration = configuration
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        schedulerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await performSync()
                do {
                    try await Task.sleep(for: .seconds(configuration.syncIntervalSeconds))
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        schedulerTask?.cancel()
        schedulerTask = nil
        isRunning = false
    }

    func syncNow() async {
        await performSync()
    }

    private func performSync() async {
        status = .syncing
        do {
            let entry = try await syncService.sync()
            appendLog(entry)
            if entry.success {
                status = .idle
            } else {
                status = .error(entry.errorMessage ?? "Unknown error")
            }
        } catch {
            let entry = SyncLogEntry(
                success: false,
                errorMessage: error.localizedDescription
            )
            appendLog(entry)
            status = .error(error.localizedDescription)
        }
        lastSyncDate = Date()
    }

    private func appendLog(_ entry: SyncLogEntry) {
        recentLogs.insert(entry, at: 0)
        if recentLogs.count > configuration.maxLogEntries {
            recentLogs = Array(recentLogs.prefix(configuration.maxLogEntries))
        }
    }
}
