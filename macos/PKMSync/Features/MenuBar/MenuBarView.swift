import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel
    @Environment(\.openSettings)
    private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            syncStatusSection
            Divider()
            updateSection
            Divider()
            footerSection
        }
        .frame(width: 280)
        .task {
            viewModel.startScheduler()
            await viewModel.refreshConflicts()
            await viewModel.refreshRecentFiles()
        }
    }

    // MARK: - Sync Status

    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: viewModel.status.iconName)
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
                .controlSize(.small)
                .disabled(viewModel.status == .syncing)
            }

            HStack(spacing: 12) {
                if viewModel.hasConflicts {
                    Label {
                        Text("\(viewModel.conflicts.count) conflict\(viewModel.conflicts.count == 1 ? "" : "s")")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }

                if !viewModel.recentLogs.isEmpty {
                    let recent = viewModel.recentLogs.prefix(5)
                    let successCount = recent.filter(\.success).count
                    Label {
                        Text("\(successCount)/\(recent.count) syncs ok")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(successCount == recent.count ? .green : .orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                viewModel.showDetailWindow()
            } label: {
                HStack {
                    Text("Show Details...")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
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

    // MARK: - Update Status

    private var updateSection: some View {
        UpdateStatusRow(
            state: viewModel.updateState,
            onCheck: {
                Task { await viewModel.checkForUpdates() }
            },
            onDownloadAndInstall: {
                Task { await viewModel.downloadAndInstall() }
            },
            onViewReleaseNotes: {
                viewModel.viewReleaseNotes()
            }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                openSettings()
            } label: {
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
