import SwiftUI

/// Container view displaying a monthly calendar with summary and report indicators
struct InsightsView: View {
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: CalendarViewModel
    @ObservedObject private var notificationHandler = NotificationHandler.shared
    @State private var selectedSummary: Summary?
    @State private var selectedReport: Report?
    @State private var taskStats: TaskStatsResponse?

    init(apiClient: any APIClientProtocol, calendar: Calendar = .current, today: Date = Date()) {
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: CalendarViewModel(
            apiClient: apiClient,
            calendar: calendar,
            today: today
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading insights...")

                case .loaded:
                    ScrollView {
                        VStack(spacing: 16) {
                            // Tasks section
                            NavigationLink {
                                TaskListView(apiClient: apiClient)
                            } label: {
                                HStack {
                                    Label("Tasks", systemImage: "checklist")
                                        .font(.headline)
                                    Spacer()
                                    if let stats = taskStats, stats.open > 0 {
                                        Text("\(stats.open) open")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .accessibilityIdentifier("TasksNavigationLink")

                            // Dispatch section
                            NavigationLink {
                                DispatchListView(apiClient: apiClient)
                            } label: {
                                HStack {
                                    Label("Dispatch Jobs", systemImage: "hammer.circle")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .accessibilityIdentifier("DispatchNavigationLink")

                            CalendarView(
                                viewModel: viewModel,
                                onSummaryTap: { summary in
                                    selectedSummary = summary
                                },
                                onReportTap: { report in
                                    selectedReport = report
                                }
                            )

                            if !viewModel.hasInsightsThisMonth {
                                Text("No insights this month")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .accessibilityIdentifier("EmptyMonthLabel")
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refresh()
                        await loadTaskStats()
                    }

                case let .error(error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadData() }
                    }
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                if notificationHandler.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await notificationHandler.markAllAsViewed()
                                await viewModel.refresh()
                            }
                        } label: {
                            Text("Mark All Read")
                        }
                        .accessibilityIdentifier("MarkAllReadButton")
                    }
                }
            }
            .navigationDestination(item: $selectedSummary) { summary in
                SummaryDetailView(summary: summary, apiClient: apiClient)
            }
            .navigationDestination(item: $selectedReport) { report in
                ReportDetailView(report: report, apiClient: apiClient)
            }
            .navigationDestination(for: String.self) { documentPath in
                DocumentLoaderView(documentPath: documentPath, apiClient: apiClient)
            }
        }
        .task {
            await viewModel.loadData()
            await loadTaskStats()
        }
        .accessibilityIdentifier("InsightsView")
    }

    private func loadTaskStats() async {
        do {
            taskStats = try await apiClient.getTaskStats()
        } catch {
            // Non-critical, task stats badge just won't show
        }
    }
}
