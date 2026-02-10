import SwiftUI
import Textual

/// Detail view for a weekly report, renders markdown content
struct ReportDetailView: View {
    let report: Report
    @StateObject private var viewModel: InsightDetailViewModel

    init(report: Report, apiClient: any APIClientProtocol) {
        self.report = report
        _viewModel = StateObject(wrappedValue: InsightDetailViewModel(
            key: report.id,
            apiClient: apiClient
        ))
    }

    var body: some View {
        VStack {
            switch viewModel.contentState {
            case .loading:
                LoadingView(message: "Loading report...")

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
        .navigationTitle("Week of \(report.weekOf)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
        .accessibilityIdentifier("ReportDetailView")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
