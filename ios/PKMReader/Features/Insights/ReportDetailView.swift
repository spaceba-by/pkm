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
        Group {
            switch viewModel.contentState {
            case .loading:
                LoadingView(message: "Loading report...")

            case .loaded(let content):
                ScrollView {
                    StructuredText(markdown: content)
                        .textSelection(.enabled)
                        .padding()
                }

            case .error(let error):
                ErrorView(error: error) {
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
