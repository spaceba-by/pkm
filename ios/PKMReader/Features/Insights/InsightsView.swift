import SwiftUI

/// Container view displaying a monthly calendar with summary and report indicators
struct InsightsView: View {
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedSummary: Summary?
    @State private var selectedReport: Report?

    init(apiClient: any APIClientProtocol, today: Date = Date()) {
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: CalendarViewModel(apiClient: apiClient, today: today))
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
                    }

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadData() }
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationDestination(item: $selectedSummary) { summary in
                SummaryDetailView(summary: summary, apiClient: apiClient)
            }
            .navigationDestination(item: $selectedReport) { report in
                ReportDetailView(report: report, apiClient: apiClient)
            }
        }
        .task {
            await viewModel.loadData()
        }
        .accessibilityIdentifier("InsightsView")
    }
}
