import SwiftUI

struct SyncLogSection: View {
    let entries: [SyncLogEntry]
    let onViewLog: (SyncLogEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Syncs Yet",
                systemImage: "arrow.triangle.2.circlepath",
                description: Text("Sync logs will appear here after the first sync.")
            )
        } else {
            List(entries) { entry in
                SyncLogRow(entry: entry) {
                    onViewLog(entry)
                }
            }
        }
    }
}

struct SyncLogRow: View {
    let entry: SyncLogEntry
    let onViewLog: () -> Void
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
            if !entry.success {
                Button {
                    onViewLog()
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .font(.caption2)
                .help("View full log")
            }
            Text(formatDuration(entry.duration))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
