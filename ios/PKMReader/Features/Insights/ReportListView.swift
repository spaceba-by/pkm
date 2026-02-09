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

            case .error(let errorMessage):
                ErrorView(error: GenericError(message: errorMessage)) {
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
                NavigationLink {
                    ReportDetailView(report: report, apiClient: viewModel.apiClient)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Week of \(report.weekOf)")
                                .font(.headline)
                            Text(report.modified, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("ReportRow_\(report.weekOf)")
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("ReportList")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
