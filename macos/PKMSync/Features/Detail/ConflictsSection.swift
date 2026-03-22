import SwiftUI

struct ConflictsSection: View {
    let conflicts: [ConflictFile]
    let vaultPath: String
    let onDiff: (ConflictFile) -> Void
    let onResolve: (ConflictFile, ConflictResolution) -> Void

    var body: some View {
        if conflicts.isEmpty {
            ContentUnavailableView(
                "No Conflicts",
                systemImage: "checkmark.shield",
                description: Text("All files are in sync.")
            )
        } else {
            List(conflicts) { conflict in
                ConflictRow(
                    conflict: conflict,
                    vaultPath: vaultPath,
                    onDiff: { onDiff(conflict) },
                    onResolve: { resolution in onResolve(conflict, resolution) }
                )
            }
        }
    }
}

struct ConflictRow: View {
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
    }
}
