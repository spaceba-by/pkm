import SwiftUI

struct DispatchDetailView: View {
    let job: DispatchJob
    let apiClient: any APIClientProtocol

    @State private var jobDetail: JobDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status header
                HStack {
                    Image(systemName: job.statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                    Text(job.status.capitalized)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                    Spacer()
                    Text(job.agentType)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }

                // Task description
                GroupBox("Task") {
                    Text(job.taskDescription)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Timestamps
                GroupBox("Timeline") {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Created", value: job.created.formatted())
                        if let started = job.startedAt {
                            LabeledContent("Started", value: started.formatted())
                        }
                        if let completed = job.completedAt {
                            LabeledContent("Completed", value: completed.formatted())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Error
                if let error = job.error {
                    GroupBox("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Artifacts
                if let artifacts = jobDetail?.job.artifacts, !artifacts.isEmpty {
                    GroupBox("Artifacts") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(artifacts, id: \.self) { artifact in
                                Label(artifact, systemImage: "doc")
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Result content
                if let result = jobDetail?.result {
                    GroupBox("Result") {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .padding()
        }
        .navigationTitle("Job Details")
        .task {
            await loadDetail()
        }
    }

    private var statusColor: Color {
        switch job.status {
        case "pending": .orange
        case "running": .blue
        case "completed": .green
        case "failed": .red
        default: .gray
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            jobDetail = try await apiClient.getJob(jobId: job.jobId)
        } catch {
            errorMessage = "Failed to load details"
        }
    }
}
