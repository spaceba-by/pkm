import SwiftUI

/// Prompt template and model fields of the workflow form
struct WorkflowPromptSection: View {
    @Binding var draft: WorkflowDraft
    let onShowVariables: () -> Void

    var body: some View {
        Section {
            Picker("Model", selection: $draft.model) {
                ForEach(WorkflowModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .accessibilityIdentifier("WorkflowModelPicker")

            VStack(alignment: .leading, spacing: 4) {
                Text("System prompt (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.systemPrompt)
                    .frame(minHeight: 60)
                    .font(.callout)
                    .accessibilityIdentifier("WorkflowSystemPromptEditor")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Prompt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Insert variable", action: onShowVariables)
                        .font(.caption)
                        .accessibilityIdentifier("WorkflowInsertVariableButton")
                }
                TextEditor(text: $draft.userPrompt)
                    .frame(minHeight: 140)
                    .font(.system(.callout, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("WorkflowUserPromptEditor")
            }

            Stepper(
                "Max tokens: \(draft.maxTokens)",
                value: $draft.maxTokens,
                in: WorkflowDraft.maxTokensRange,
                step: 512
            )

            VStack(alignment: .leading) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(String(format: "%.1f", draft.temperature))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $draft.temperature, in: 0 ... 1, step: 0.1)
            }
        } header: {
            Text("Prompt")
        } footer: {
            Text(
                "Use {{document.body}}, {{documents.content}}, {{command.args}} and other variables; "
                    + "they are replaced when the workflow runs."
            )
        }
    }
}

/// Output destination fields of the workflow form
struct WorkflowOutputSection: View {
    @Binding var draft: WorkflowDraft

    var body: some View {
        Section {
            Picker("Destination", selection: $draft.destination) {
                ForEach(WorkflowDestination.allCases, id: \.self) { destination in
                    Label(destination.displayName, systemImage: destination.icon).tag(destination)
                }
            }
            .accessibilityIdentifier("WorkflowDestinationPicker")

            if draft.destination == .s3 {
                TextField("_agent/workflows/{{workflow.name}}/{{now.date}}-{{run.id}}.md", text: $draft.outputPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.callout, design: .monospaced))
                    .accessibilityIdentifier("WorkflowOutputPathField")
            }
        } header: {
            Text("Output")
        } footer: {
            Text(footerText)
        }
    }

    private var footerText: String {
        switch draft.destination {
        case .s3:
            "Written as a markdown file. The path may use template variables and must stay under _agent/, "
                + "which the processing pipeline ignores."
        case .dynamodb:
            "The result is kept on the run record only and shown in the run history."
        case .notification:
            "The first 500 characters are sent as a push notification; the full result stays on the run record."
        }
    }
}
