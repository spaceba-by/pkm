import SwiftUI

/// View displaying a list of daily AI summaries
struct SummaryListView: View {
    @StateObject private var viewModel: SummariesViewModel

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SummariesViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading summaries...")

            case .loaded(let summaries):
                summaryList(summaries)

            case .empty:
                EmptyStateView(
                    icon: "doc.plaintext",
                    title: "No Summaries",
                    message: "No daily summaries available yet"
                )

            case .error(let errorMessage):
                ErrorView(error: GenericError(message: errorMessage)) {
                    Task { await viewModel.loadSummaries() }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadSummaries()
        }
    }

    private func summaryList(_ summaries: [Summary]) -> some View {
        List {
            ForEach(summaries) { summary in
                NavigationLink {
                    SummaryDetailView(summary: summary, apiClient: viewModel.apiClient)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.date)
                                .font(.headline)
                            Text(summary.modified, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("SummaryRow_\(summary.date)")
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("SummaryList")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
