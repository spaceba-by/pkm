import SwiftUI

/// View for browsing extracted tasks from PKM documents
struct TaskListView: View {
    let apiClient: any APIClientProtocol
    @State private var viewModel: TaskListViewModel

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: TaskListViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading tasks...")
                    .accessibilityIdentifier("tasksLoadingIndicator")
            case .loaded:
                taskContent
            case let .error(message):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                }
                .accessibilityIdentifier("tasksErrorView")
            }
        }
        .navigationTitle("Tasks")
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder private var taskContent: some View {
        if viewModel.tasks.isEmpty {
            ContentUnavailableView {
                Label("No Tasks", systemImage: "checkmark.circle")
            } description: {
                Text("No \(viewModel.selectedStatus.displayName.lowercased()) tasks found.")
            }
            .accessibilityIdentifier("tasksEmptyView")
        } else {
            List {
                if let stats = viewModel.stats {
                    statsSection(stats: stats)
                }

                ForEach(viewModel.tasks) { task in
                    TaskRow(task: task, apiClient: apiClient)
                        .onAppear {
                            if task.id == viewModel.tasks.last?.id, viewModel.hasMorePages {
                                Task { await viewModel.loadMoreTasks() }
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("tasksList")
        }
    }

    private func statsSection(stats: TaskStatsResponse) -> some View {
        Section {
            HStack {
                StatBadge(label: "Open", count: stats.open, color: .orange)
                Spacer()
                StatBadge(label: "Done", count: stats.completed, color: .green)
                Spacer()
                StatBadge(label: "Total", count: stats.total, color: .secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

/// A single task row
struct TaskRow: View {
    let task: ExtractedTask
    let apiClient: any APIClientProtocol

    var body: some View {
        // Use destination-based NavigationLink instead of value-based to avoid
        // SwiftUI scope resolution issues when this view is a pushed destination.
        // See PR #127 for details on this pattern.
        NavigationLink {
            DocumentLoaderView(documentPath: task.documentPath, apiClient: apiClient)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.description)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    HStack(spacing: 8) {
                        Label(task.documentName, systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let priority = task.priority {
                            PriorityBadge(priority: priority)
                        }

                        if let dueDate = task.dueDate {
                            Label(dueDate, systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: task.displayMarker)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("taskRow-\(task.taskId)")
    }
}

/// Priority indicator badge
struct PriorityBadge: View {
    let priority: String

    private var color: Color {
        switch priority {
        case "high": .red
        case "medium": .orange
        case "low": .blue
        default: .secondary
        }
    }

    var body: some View {
        Text(priority.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Helper view that loads a document by path and displays its detail
struct DocumentLoaderView: View {
    let documentPath: String
    let apiClient: any APIClientProtocol
    @State private var document: Document?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let document {
                DocumentDetailView(document: document, apiClient: apiClient)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else {
                ProgressView("Loading document...")
            }
        }
        .task {
            do {
                document = try await apiClient.getDocument(key: documentPath)
            } catch {
                errorMessage = "Failed to load document"
            }
        }
    }
}

/// Stats summary badge
struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
