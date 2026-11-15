import SwiftUI

/// Form view for creating or editing a custom agent workflow
struct WorkflowFormView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var draft: WorkflowDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isPresentingVariables = false

    private let isEditing: Bool
    private let onSubmit: (WorkflowRequest) async throws -> Workflow

    /// Create mode
    init(onSave: @escaping (WorkflowRequest) async throws -> Workflow) {
        _draft = State(initialValue: WorkflowDraft())
        isEditing = false
        onSubmit = onSave
    }

    /// Edit mode
    init(workflow: Workflow, onUpdate: @escaping (WorkflowRequest) async throws -> Workflow) {
        _draft = State(initialValue: WorkflowDraft(workflow: workflow))
        isEditing = true
        onSubmit = onUpdate
    }

    var body: some View {
        Form {
            detailsSection
            WorkflowTriggerSection(draft: $draft)
            WorkflowFilterSection(draft: $draft)
            WorkflowPromptSection(draft: $draft) {
                isPresentingVariables = true
            }
            WorkflowOutputSection(draft: $draft)
            validationSection
        }
        .navigationTitle(isEditing ? "Edit Workflow" : "New Workflow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Create") {
                    Task { await save() }
                }
                .disabled(!draft.isValid || isSaving)
                .accessibilityIdentifier("SaveWorkflowButton")
            }
        }
        .sheet(isPresented: $isPresentingVariables) {
            NavigationStack {
                WorkflowVariablesView { variable in
                    draft.userPrompt += variable.placeholder
                }
            }
            .presentationDetents([.medium, .large])
        }
        .disabled(isSaving)
        .accessibilityIdentifier("WorkflowFormView")
    }

    private var detailsSection: some View {
        Section {
            TextField("Name (e.g. action-items)", text: $draft.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("WorkflowNameField")
            TextField("Description (optional)", text: $draft.description)
                .accessibilityIdentifier("WorkflowDescriptionField")
            Toggle("Enabled", isOn: $draft.enabled)
        } header: {
            Text("Workflow")
        } footer: {
            Text(
                "Names are lower-case letters, digits and hyphens. Command workflows are addressed as @workflow:<name>."
            )
        }
    }

    @ViewBuilder private var validationSection: some View {
        let errors = draft.validationErrors
        if !errors.isEmpty || errorMessage != nil {
            Section {
                ForEach(errors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            _ = try await onSubmit(draft.request())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

/// Browse template variables and insert one into the prompt
struct WorkflowVariablesView: View {
    @Environment(\.dismiss)
    private var dismiss

    let onInsert: (WorkflowTemplateVariable) -> Void

    private var scopes: [String] {
        var seen: [String] = []
        for variable in WorkflowTemplateVariable.all where !seen.contains(variable.scope) {
            seen.append(variable.scope)
        }
        return seen
    }

    var body: some View {
        List {
            ForEach(scopes, id: \.self) { scope in
                Section(scope) {
                    ForEach(WorkflowTemplateVariable.all.filter { $0.scope == scope }) { variable in
                        Button {
                            onInsert(variable)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(variable.placeholder)
                                    .font(.system(.body, design: .monospaced))
                                Text(variable.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Template Variables")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
