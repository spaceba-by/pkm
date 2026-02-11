import SwiftUI

/// View displaying a list of weekly AI reports
struct ReportListView: View {
    @StateObject private var viewModel: ReportsViewModel

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: ReportsViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading reports...")

            case .loaded(let reports):
                reportList(reports)

            case .empty:
                EmptyStateView(
                    icon: "chart.bar.doc.horizontal",
                    title: "No Reports",
                    message: "No weekly reports available yet"
                )

            case .error(let error):
                ErrorView(error: error) {
                    Task { await viewModel.loadReports() }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadReports()
        }
    }

    private func reportList(_ reports: [Report]) -> some View {
        List {
            ForEach(reports) { report in
                NavigationLink(value: report) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Week of \(report.weekOf)")
                                .font(.headline)
                            if let modified = report.modified {
                                Text(modified, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .accessibilityIdentifier("ReportRow_\(report.weekOf)")
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Report.self) { report in
            ReportDetailView(report: report, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("ReportList")
    }
}
