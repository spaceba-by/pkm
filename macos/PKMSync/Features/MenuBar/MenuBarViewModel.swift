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
    private(set) var selectedConflict: ConflictFile?
    private var diffWindow: NSWindow?
    private var logWindow: NSWindow?
    private var windowDelegate: WindowCloseDelegate?
    private var logWindowDelegate: WindowCloseDelegate?

    func showDiff(for conflict: ConflictFile) {
        // Dismiss any existing diff window before opening a new one
        tearDownWindow(&diffWindow, delegate: &windowDelegate)
        windowDelegate = nil

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

        let detailView = ConflictDetailView(
            viewModel: diffViewModel,
            onDismiss: { [weak self] in
                self?.closeDiffWindow()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Conflict: \(conflict.relativePath(from: configuration.vaultPath))"
        window.contentView = NSHostingView(rootView: detailView)
        window.center()

        let delegate = WindowCloseDelegate { [weak self] in
            guard let self else { return }
            diffWindow?.contentView = nil
            diffWindow = nil
            windowDelegate = nil
            selectedConflict = nil
        }
        window.delegate = delegate
        windowDelegate = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        diffWindow = window
    }

    private func closeDiffWindow() {
        tearDownWindow(&diffWindow, delegate: &windowDelegate)
        selectedConflict = nil
    }

    func showLog(for entry: SyncLogEntry) {
        tearDownWindow(&logWindow, delegate: &logWindowDelegate)

        let output = entry.rawOutput ?? entry.errorMessage ?? "No output available"
        let logView = SyncLogDetailView(
            timestamp: entry.timestamp,
            output: output
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Sync Log — \(entry.timestamp.formatted(date: .abbreviated, time: .standard))"
        window.contentView = NSHostingView(rootView: logView)
        window.center()

        let delegate = WindowCloseDelegate { [weak self] in
            guard let self else { return }
            logWindow?.contentView = nil
            logWindow = nil
            logWindowDelegate = nil
        }
        window.delegate = delegate
        logWindowDelegate = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logWindow = window
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

    /// Safely tear down an NSWindow: detach delegate, clear hosted SwiftUI
    /// content, close the window, then nil out the references.
    private func tearDownWindow(
        _ window: inout NSWindow?,
        delegate: inout WindowCloseDelegate?
    ) {
        window?.delegate = nil
        window?.contentView = nil
        window?.close()
        window = nil
        delegate = nil
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

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private var onClose: (@MainActor () -> Void)?

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_: Notification) {
        let closure = onClose
        onClose = nil
        if let closure {
            Task { @MainActor in closure() }
        }
    }
}
