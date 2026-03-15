import SwiftUI

struct ConflictDetailView: View {
    @Bindable var viewModel: ConflictDetailViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            diffContent
            Divider()
            actionBar
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.loadDiff()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.conflict.relativePath(from: viewModel.vaultPath))
                .font(.headline)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                if let originalDate = viewModel.conflict.originalModified {
                    Label {
                        Text("Original: \(originalDate, style: .date) \(originalDate, style: .time)")
                    } icon: {
                        Image(systemName: "doc")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let conflictDate = viewModel.conflict.conflictModified {
                    Label {
                        Text("Conflict: \(conflictDate, style: .date) \(conflictDate, style: .time)")
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var diffContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.diffLines.isEmpty {
                Text("Files are identical")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.diffLines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Keep Original") {
                viewModel.resolve(.keepOriginal)
                if viewModel.isResolved {
                    onDismiss()
                }
            }

            Button("Keep Conflict") {
                viewModel.resolve(.keepConflict)
                if viewModel.isResolved {
                    onDismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .frame(width: 14, alignment: .center)
                .foregroundStyle(prefixColor)

            Text(line.text)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(backgroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prefix: String {
        switch line.type {
        case .added: "+"
        case .removed: "-"
        case .header: "@"
        case .context: " "
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .added: .green
        case .removed: .red
        case .header: .blue
        case .context: .secondary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .added: .green.opacity(0.1)
        case .removed: .red.opacity(0.1)
        case .header: .blue.opacity(0.05)
        case .context: .clear
        }
    }
}
