import SwiftUI

struct WorkflowListView: View {
    @State private var viewModel: WorkflowListViewModel
    @State private var isPresentingCreate = false
    @State private var workflowToDelete: Workflow?

    init(apiClient: any APIClientProtocol) {
        _viewModel = State(initialValue: WorkflowListViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading workflows...")
            case .loaded:
                listContent
            case let .error(message):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadWorkflows() }
                    }
                }
            }
        }
        .navigationTitle("Workflows")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingCreate = true
                } label: {
                    Label("New Workflow", systemImage: "plus")
                }
                .accessibilityIdentifier("NewWorkflowButton")
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            NavigationStack {
                WorkflowFormView { request in
                    try await viewModel.createWorkflow(request)
                }
            }
        }
        .alert(
            "Delete Workflow?",
            isPresented: Binding(
                get: { workflowToDelete != nil },
                set: { if !$0 { workflowToDelete = nil } }
            ),
            presenting: workflowToDelete
        ) { workflow in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteWorkflow(workflow) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { workflow in
            Text("\"\(workflow.name)\" and its run history will be removed. Output files in the vault are kept.")
        }
        .refreshable {
            await viewModel.loadWorkflows()
        }
        .task {
            await viewModel.loadWorkflows()
        }
        .accessibilityIdentifier("WorkflowListView")
    }

    @ViewBuilder private var listContent: some View {
        if viewModel.workflows.isEmpty {
            ContentUnavailableView {
                Label("No Workflows", systemImage: "gearshape.2")
            } description: {
                Text(
                    "Create a workflow to run a prompt whenever a document is classified, on a schedule, or on demand."
                )
            } actions: {
                Button("New Workflow") {
                    isPresentingCreate = true
                }
            }
        } else {
            List {
                if let actionError = viewModel.actionError {
                    Section {
                        Label(actionError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                ForEach(viewModel.workflows) { workflow in
                    NavigationLink(value: workflow) {
                        WorkflowRow(workflow: workflow) { enabled in
                            Task { await viewModel.setEnabled(workflow, enabled: enabled) }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            workflowToDelete = workflow
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationDestination(for: Workflow.self) { workflow in
                WorkflowDetailView(workflow: workflow, apiClient: viewModel.apiClient) { updated in
                    viewModel.replace(updated)
                }
            }
        }
    }
}

private struct WorkflowRow: View {
    let workflow: Workflow
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workflow.trigger.type.icon)
                .font(.title3)
                .foregroundStyle(workflow.enabled ? Color.accentColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(workflow.name)
                    .font(.headline)
                Text(workflow.triggerSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: workflow.lastStatusIcon)
                    Text(lastRunText)
                }
                .font(.caption2)
                .foregroundStyle(statusColor)
            }

            Spacer()

            Toggle("Enabled", isOn: Binding(get: { workflow.enabled }, set: onToggle))
                .labelsHidden()
                .accessibilityLabel("\(workflow.name) enabled")
        }
        .padding(.vertical, 2)
    }

    private var lastRunText: String {
        guard workflow.lastStatus != nil else { return "Never run" }
        let count = workflow.runCount
        return "\(count) run\(count == 1 ? "" : "s"), last \(workflow.lastStatus ?? "")"
    }

    private var statusColor: Color {
        switch workflow.lastStatus {
        case "completed": .green
        case "failed": .red
        case "running": .blue
        default: .secondary
        }
    }
}
