import SwiftUI

struct DetailView: View {
    @Bindable var viewModel: MenuBarViewModel
    @State private var selectedTab: DetailTab = .syncLog

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Sync Log", systemImage: "clock.arrow.circlepath", value: .syncLog) {
                SyncLogSection(entries: viewModel.recentLogs) { entry in
                    viewModel.showLog(for: entry)
                }
            }

            Tab(value: .conflicts) {
                ConflictsSection(
                    conflicts: viewModel.conflicts,
                    vaultPath: viewModel.configuration.vaultPath,
                    onDiff: { conflict in viewModel.showDiff(for: conflict) },
                    onResolve: { conflict, resolution in
                        viewModel.resolveConflict(conflict, resolution: resolution)
                    }
                )
            } label: {
                Label {
                    HStack(spacing: 4) {
                        Text("Conflicts")
                        if viewModel.hasConflicts {
                            Text("\(viewModel.conflicts.count)")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.red.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.red)
                        }
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            }

            Tab("Recent Files", systemImage: "doc.text", value: .recentFiles) {
                RecentFilesSection(files: viewModel.recentFiles) { file in
                    viewModel.openInObsidian(file)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.refreshConflicts()
            await viewModel.refreshRecentFiles()
        }
    }
}

enum DetailTab: Hashable {
    case syncLog
    case conflicts
    case recentFiles
}
