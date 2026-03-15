import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
            Divider()
            syncLogSection
            if viewModel.hasConflicts {
                Divider()
                conflictsSection
            }
            if !viewModel.recentFiles.isEmpty {
                Divider()
                recentFilesSection
            }
            Divider()
            footerSection
        }
        .frame(width: 320)
        .task {
            viewModel.startScheduler()
            await viewModel.refreshConflicts()
            await viewModel.refreshRecentFiles()
        }
    }

    private var statusHeader: some View {
        HStack {
            Image(systemName: viewModel.status.iconName)
                .symbolEffect(.rotate, isActive: viewModel.status == .syncing)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.status.label)
                    .font(.headline)
                if let lastSync = viewModel.lastSyncDate {
                    Text("Last sync: \(lastSync, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Sync Now") {
                Task {
                    await viewModel.syncNow()
                }
            }
            .disabled(viewModel.status == .syncing)
        }
        .padding(12)
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle:
            .green
        case .syncing:
            .blue
        case .error:
            .red
        }
    }

    private var syncLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent Syncs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if viewModel.recentLogs.isEmpty {
                Text("No syncs yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else {
                ForEach(viewModel.recentLogs.prefix(5)) { entry in
                    SyncLogRow(entry: entry)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Conflicts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.conflicts.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(viewModel.conflicts) { conflict in
                ConflictRow(
                    conflict: conflict,
                    vaultPath: viewModel.configuration.vaultPath,
                    onDiff: {
                        viewModel.showDiff(for: conflict)
                    },
                    onResolve: { resolution in
                        viewModel.resolveConflict(conflict, resolution: resolution)
                    }
                )
            }
            .padding(.bottom, 4)
        }
    }

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recently Modified")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(viewModel.recentFiles) { file in
                Button {
                    viewModel.openInObsidian(file)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .font(.body)
                            Text(file.modified, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
            .padding(.bottom, 4)
        }
    }

    private var footerSection: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gear")
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
    }
}

private struct SyncLogRow: View {
    let entry: SyncLogEntry
    @State private var isExpanded = false

    var body: some View {
        HStack {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .font(.caption)
            VStack(alignment: .leading) {
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                if entry.filesTransferred > 0 {
                    Text("\(entry.filesTransferred) files synced")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let error = entry.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(isExpanded ? nil : 2)
                        .help(error)
                        .onTapGesture {
                            isExpanded.toggle()
                        }
                }
            }
            Spacer()
            Text(formatDuration(entry.duration))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            "<1s"
        } else if duration < 60 {
            "\(Int(duration))s"
        } else {
            "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
        }
    }
}

private struct ConflictRow: View {
    let conflict: ConflictFile
    let vaultPath: String
    let onDiff: () -> Void
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(conflict.relativePath(from: vaultPath))
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(conflict.relativePath(from: vaultPath))
            Spacer()
            Button {
                onDiff()
            } label: {
                Image(systemName: "eye")
            }
            .font(.caption2)
            .help("View diff")
            Button("Keep Original") {
                onResolve(.keepOriginal)
            }
            .font(.caption2)
            Button("Keep Conflict") {
                onResolve(.keepConflict)
            }
            .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}
