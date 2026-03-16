import SwiftUI

struct DispatchListView: View {
    @State private var viewModel: DispatchListViewModel

    init(apiClient: any APIClientProtocol) {
        _viewModel = State(initialValue: DispatchListViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading jobs...")
            case .loaded:
                jobListContent
            case .error(let message):
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadJobs() }
                    }
                }
            }
        }
        .navigationTitle("Dispatch Jobs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(DispatchListViewModel.StatusFilter.allCases, id: \.self) { status in
                        Button {
                            Task { await viewModel.changeFilter(to: status) }
                        } label: {
                            HStack {
                                Text(status.displayName)
                                if viewModel.selectedStatus == status {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable {
            await viewModel.loadJobs()
        }
        .task {
            await viewModel.loadJobs()
        }
    }

    @ViewBuilder private var jobListContent: some View {
        if viewModel.jobs.isEmpty {
            ContentUnavailableView {
                Label("No Jobs", systemImage: "tray")
            } description: {
                Text("No dispatch jobs found.")
            }
        } else {
            List {
                ForEach(viewModel.jobs) { job in
                    NavigationLink(value: job) {
                        DispatchJobRow(job: job)
                    }
                }
            }
            .navigationDestination(for: DispatchJob.self) { job in
                DispatchDetailView(job: job, apiClient: viewModel.apiClient)
            }
        }
    }
}

private struct DispatchJobRow: View {
    let job: DispatchJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: job.statusIcon)
                    .foregroundStyle(statusColor)
                Text(job.taskDescription)
                    .lineLimit(2)
            }
            HStack {
                Text(job.agentType)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                Text(job.status.capitalized)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Spacer()

                Text(job.created, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
}
