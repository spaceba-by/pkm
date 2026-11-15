import SwiftUI

struct WorkflowDetailView: View {
    @State private var viewModel: WorkflowDetailViewModel
    @State private var isPresentingEdit = false
    @State private var isPresentingRunPrompt = false
    @State private var runDocumentPath = ""
    private let onUpdate: (Workflow) -> Void

    init(workflow: Workflow, apiClient: any APIClientProtocol, onUpdate: @escaping (Workflow) -> Void) {
        _viewModel = State(initialValue: WorkflowDetailViewModel(workflow: workflow, apiClient: apiClient))
        self.onUpdate = onUpdate
    }

    private var workflow: Workflow {
        viewModel.workflow
    }

    var body: some View {
        List {
            headerSection
            configurationSection
            promptSection
            runsSection
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isPresentingEdit = true
                }
                .accessibilityIdentifier("EditWorkflowButton")
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            NavigationStack {
                WorkflowFormView(workflow: workflow) { request in
                    let updated = try await viewModel.apiClient.updateWorkflow(id: workflow.id, request: request)
                    viewModel.apply(updated)
                    onUpdate(updated)
                    return updated
                }
            }
        }
        .alert("Run Workflow", isPresented: $isPresentingRunPrompt) {
            TextField("Document path (optional)", text: $runDocumentPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Run") {
                Task { await viewModel.runNow(documentPath: runDocumentPath) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(runPromptMessage)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadRuns()
        }
        .accessibilityIdentifier("WorkflowDetailView")
    }

    private var runPromptMessage: String {
        workflow.trigger.type == .schedule
            ? "Leave the path empty to run over recent matching documents."
            : "Enter a vault path such as meetings/2026-01-05.md, or leave empty to use the filter."
    }

    private var headerSection: some View {
        Section {
            HStack {
                Label(workflow.trigger.type.displayName, systemImage: workflow.trigger.type.icon)
                Spacer()
                Text(workflow.enabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(workflow.enabled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                    .foregroundStyle(workflow.enabled ? .green : .secondary)
                    .clipShape(Capsule())
            }
            if !workflow.description.isEmpty {
                Text(workflow.description)
                    .foregroundStyle(.secondary)
            }
            Button {
                runDocumentPath = ""
                isPresentingRunPrompt = true
            } label: {
                if viewModel.isStartingRun {
                    ProgressView()
                } else {
                    Label("Run Now", systemImage: "play.fill")
                }
            }
            .disabled(viewModel.isStartingRun)
            .accessibilityIdentifier("RunWorkflowButton")
            if let message = viewModel.statusMessage {
                Label(message, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var configurationSection: some View {
        Section("Configuration") {
            LabeledContent("Trigger", value: workflow.triggerSummary)
            LabeledContent("Filter", value: workflow.filter.summary)
            if let days = workflow.filter.lookbackDays, workflow.trigger.type == .schedule {
                LabeledContent("Lookback", value: "\(days) day\(days == 1 ? "" : "s")")
            }
            LabeledContent("Output", value: workflow.output.destination.displayName)
            if let path = workflow.output.path {
                LabeledContent("Path", value: path)
                    .font(.caption)
            }
            LabeledContent("Cooldown", value: "\(workflow.cooldownMinutes) min")
            LabeledContent("Runs", value: "\(workflow.runCount)")
            if let nextRun = workflow.nextRun {
                LabeledContent("Next run", value: nextRun)
            }
            if let lastRun = workflow.lastRun {
                LabeledContent("Last run", value: "\(lastRun) (\(workflow.lastStatus ?? "unknown"))")
            }
        }
    }

    private var promptSection: some View {
        Section("Prompt") {
            LabeledContent("Model", value: workflow.prompt.model.displayName)
            if let system = workflow.prompt.system, !system.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System").font(.caption).foregroundStyle(.secondary)
                    Text(system).font(.callout)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("User").font(.caption).foregroundStyle(.secondary)
                Text(workflow.prompt.user)
                    .font(.system(.callout, design: .monospaced))
            }
        }
    }

    private var runsSection: some View {
        Section {
            if viewModel.runs.isEmpty, !viewModel.isLoadingRuns {
                Text("No runs yet")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.runs) { run in
                NavigationLink {
                    WorkflowRunDetailView(run: run)
                } label: {
                    WorkflowRunRow(run: run)
                }
            }
            if viewModel.hasMoreRuns {
                Button("Load more") {
                    Task { await viewModel.loadMoreRuns() }
                }
                .disabled(viewModel.isLoadingRuns)
            }
            if viewModel.isLoadingRuns {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Runs")
        }
    }
}

private struct WorkflowRunRow: View {
    let run: WorkflowRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: run.statusIcon)
                    .foregroundStyle(statusColor)
                Text(run.subjectText)
                    .lineLimit(1)
                Spacer()
                if let duration = run.durationText {
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Text(run.status.capitalized)
                    .foregroundStyle(statusColor)
                if let trigger = run.trigger {
                    Text(trigger.capitalized)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                Spacer()
                if let started = run.started {
                    Text(started)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch run.status {
        case "running": .blue
        case "completed": .green
        case "failed": .red
        default: .gray
        }
    }
}
