import SwiftUI

/// Container view with segmented control for summaries and reports
struct InsightsView: View {
    let apiClient: any APIClientProtocol
    @State private var selectedSegment: InsightSegment = .summaries

    enum InsightSegment: String, CaseIterable {
        case summaries = "Summaries"
        case reports = "Reports"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Insights", selection: $selectedSegment) {
                    ForEach(InsightSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedSegment {
                case .summaries:
                    SummaryListView(apiClient: apiClient)
                case .reports:
                    ReportListView(apiClient: apiClient)
                }
            }
            .navigationTitle("Insights")
        }
        .accessibilityIdentifier("InsightsView")
    }
}
