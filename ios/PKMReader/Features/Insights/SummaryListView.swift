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

            case let .loaded(summaries):
                summaryList(summaries)

            case .empty:
                EmptyStateView(
                    icon: "doc.plaintext",
                    title: "No Summaries",
                    message: "No daily summaries available yet"
                )

            case let .error(error):
                ErrorView(error: error) {
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
                NavigationLink(value: summary) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.date)
                                .font(.headline)
                            if let modified = summary.modified {
                                Text(modified, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Summary for \(summary.date)")
                .accessibilityIdentifier("SummaryRow_\(summary.date)")
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Summary.self) { summary in
            SummaryDetailView(summary: summary, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("SummaryList")
    }
}
