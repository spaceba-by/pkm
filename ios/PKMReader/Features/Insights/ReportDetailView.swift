import SwiftUI
import Textual

/// Detail view for a weekly report, renders markdown content
struct ReportDetailView: View {
    let report: Report
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: InsightDetailViewModel

    init(report: Report, apiClient: any APIClientProtocol) {
        self.report = report
        self.apiClient = apiClient
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
        .navigationTitle("Week of \(report.weekOf)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
            if !report.viewed {
                try? await apiClient.markReportViewed(week: report.weekOf)
                NotificationHandler.shared.decrementUnreadCount()
            }
        }
        .accessibilityIdentifier("ReportDetailView")
    }
}
