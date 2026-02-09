import SwiftUI
import Textual

/// Detail view for a daily summary, renders markdown content
struct SummaryDetailView: View {
    let summary: Summary
    @StateObject private var viewModel: InsightDetailViewModel

    init(summary: Summary, apiClient: any APIClientProtocol) {
        self.summary = summary
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

            case .loaded(let content):
                ScrollView {
                    StructuredText(markdown: content)
                        .textSelection(.enabled)
                        .padding()
                }

            case .error(let errorMessage):
                ErrorView(error: GenericError(message: errorMessage)) {
                    Task { await viewModel.loadContent() }
                }
            }
        }
        .navigationTitle("Summary: \(summary.date)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
        .accessibilityIdentifier("SummaryDetailView")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
