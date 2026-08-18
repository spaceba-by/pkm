import Foundation
import Observation

@MainActor
@Observable
final class SyncScheduler: SyncSchedulerProtocol {
    private let syncService: SyncServiceProtocol
    private let configuration: SyncConfiguration

    private(set) var isRunning = false
    /// True from the moment a run starts until it records its outcome. Distinct
    /// from `status`, which settles to `.idle`/`.error` per run and so cannot say
    /// whether rclone is still working.
    private(set) var isSyncInFlight = false
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

    /// Runs one sync, unless one is already in flight.
    ///
    /// rclone bisync holds a lock per path pair, so a second run started while
    /// one is working dies on that lock within a second — and on the way out it
    /// resets `status`, wiping the live progress of the run that is doing the
    /// real work and painting the popover red. `@MainActor` does not prevent the
    /// overlap on its own: a scheduled tick and a manual "Sync Now" both suspend
    /// at the `await` below, so they interleave freely.
    private func performSync() async {
        guard !isSyncInFlight else { return }
        isSyncInFlight = true
        defer { isSyncInFlight = false }

        status = .syncing(SyncProgress())

        // rclone reports progress from a background thread. Funnelling snapshots
        // through a stream keeps them ordered on the way to the main actor;
        // buffering only the newest drops updates the UI would never have drawn.
        let (updates, continuation) = AsyncStream<SyncProgress>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        let consumer = Task { @MainActor [weak self] in
            for await progress in updates {
                self?.status = .syncing(progress)
            }
        }

        let result: Result<SyncLogEntry, Error>
        do {
            let entry = try await syncService.sync { continuation.yield($0) }
            result = .success(entry)
        } catch {
            result = .failure(error)
        }

        // Let the consumer finish before overwriting status with the outcome.
        continuation.finish()
        await consumer.value

        switch result {
        case let .success(entry):
            appendLog(entry)
            if entry.success {
                status = .idle
            } else {
                status = .error(entry.errorMessage ?? "Unknown error")
            }
        case let .failure(error):
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
        // Newest first by *start* time, which is what the rows display. Ordering
        // by completion instead would float a long run above the shorter ones
        // that started after it.
        recentLogs.append(entry)
        recentLogs.sort { $0.timestamp > $1.timestamp }
        if recentLogs.count > configuration.maxLogEntries {
            recentLogs = Array(recentLogs.prefix(configuration.maxLogEntries))
        }
    }
}
