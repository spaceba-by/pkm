import SwiftUI

struct UpdateStatusRow: View {
    let state: UpdateState
    let onCheck: () -> Void
    let onDownloadAndInstall: () -> Void
    let onViewReleaseNotes: () -> Void
    let onRevealBackup: (String) -> Void

    var body: some View {
        switch state {
        case .idle:
            Button {
                onCheck()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                    Text("Check for Updates...")
                        .font(.caption)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case .checking:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

        case let .available(version):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.tint)
                    Text("Update Available: v\(version)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button("Download & Install") {
                        onDownloadAndInstall()
                    }
                    .controlSize(.small)
                    Button("Release Notes") {
                        onViewReleaseNotes()
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderless)
                }
            }

        case let .downloading(progress):
            HStack {
                ProgressView(value: progress)
                    .frame(maxWidth: .infinity)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

        case .readyToInstall:
            Button {
                onDownloadAndInstall()
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.down.circle.fill")
                        .foregroundStyle(.green)
                    Text("Restart to Update")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case let .error(message):
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                Spacer()
                Button("Retry") { onCheck() }
                    .controlSize(.small)
            }

        // The error text is too long for the row, so the backup location gets
        // its own lines and a way to open it.
        case let .recoveryNeeded(message, backupPath):
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Update failed and the previous version could not be put back.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .help(message)
                Text("Your previous version is at:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(backupPath)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Show in Finder") {
                    onRevealBackup(backupPath)
                }
                .controlSize(.small)
            }

        case .upToDate:
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("Up to date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

enum UpdateState: Equatable {
    case idle
    case checking
    case available(version: String)
    case downloading(progress: Double)
    case readyToInstall
    case error(message: String)
    case recoveryNeeded(message: String, backupPath: String)
    case upToDate
}
