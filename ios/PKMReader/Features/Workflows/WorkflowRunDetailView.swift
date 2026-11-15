import SwiftUI

struct WorkflowRunDetailView: View {
    let run: WorkflowRun

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: run.statusIcon)
                        .font(.title2)
                    Text(run.status.capitalized)
                        .font(.title2)
                    Spacer()
                    if let trigger = run.trigger {
                        Text(trigger.capitalized)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(statusColor)

                GroupBox("Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let documentPath = run.documentPath {
                            LabeledContent("Document", value: documentPath)
                        }
                        if let count = run.documentCount {
                            LabeledContent("Documents", value: "\(count)")
                        }
                        if let started = run.started {
                            LabeledContent("Started", value: started)
                        }
                        if let completed = run.completed {
                            LabeledContent("Completed", value: completed)
                        }
                        if let duration = run.durationText {
                            LabeledContent("Duration", value: duration)
                        }
                        if let model = run.modelId {
                            LabeledContent("Model", value: model)
                        }
                        if let input = run.inputTokens, let output = run.outputTokens {
                            LabeledContent("Tokens", value: "\(input) in / \(output) out")
                        }
                        if let key = run.outputS3Key {
                            LabeledContent("Output", value: key)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = run.error {
                    GroupBox("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let result = run.result, !result.isEmpty {
                    GroupBox("Result") {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("WorkflowRunDetailView")
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
