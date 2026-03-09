import SwiftUI
import Textual

/// Detail view for a daily summary, renders markdown content
struct SummaryDetailView: View {
    let summary: Summary
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: InsightDetailViewModel

    init(summary: Summary, apiClient: any APIClientProtocol) {
        self.summary = summary
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: InsightDetailViewModel(
            key: summary.id,
            apiClient: apiClient
        ))
    }

    var body: some View {
        Group {
            switch viewModel.contentState {
            case .loading:
                LoadingView(message: "Loading summary...")

            case let .loaded(content):
                ScrollView {
                    StructuredText(markdown: content)
                        .textSelection(.enabled)
                        .padding()
                }

            case let .error(error):
                ErrorView(error: error) {
                    Task { await viewModel.loadContent() }
                }
            }
        }
        .navigationTitle("Summary: \(summary.date)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
            if !summary.viewed {
                try? await apiClient.markSummaryViewed(date: summary.date)
                NotificationHandler.shared.decrementUnreadCount()
            }
        }
        .accessibilityIdentifier("SummaryDetailView")
    }
}
