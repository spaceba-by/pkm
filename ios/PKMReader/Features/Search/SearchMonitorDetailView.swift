import SwiftUI

/// Detail view for a single search monitor, showing config and summaries
struct SearchMonitorDetailView: View {
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: SearchMonitorDetailViewModel
    @State private var showingEditForm = false
    @State private var actionError: Error?

    init(monitorId: String, apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
        _viewModel = StateObject(
            wrappedValue: SearchMonitorDetailViewModel(monitorId: monitorId, apiClient: apiClient)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading monitor...")

            case .loaded:
                if let monitor = viewModel.monitor {
                    monitorContent(monitor)
                }

            case let .error(error):
                ErrorView(error: error) {
                    Task { await viewModel.loadDetail() }
                }
            }
        }
        .navigationTitle(viewModel.monitor?.name ?? "Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.monitor != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEditForm = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            Task {
                                do {
                                    try await viewModel.togglePauseResume()
                                } catch {
                                    actionError = error
                                }
                            }
                        } label: {
                            if viewModel.monitor?.status == .active {
                                Label("Pause", systemImage: "pause.circle")
                            } else {
                                Label("Resume", systemImage: "play.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("MonitorActions")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            if let monitor = viewModel.monitor {
                NavigationStack {
                    SearchMonitorFormView(
                        monitor: monitor
                    ) { request in
                        try await viewModel.updateMonitor(request: request)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadDetail()
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError?.localizedDescription ?? "An unknown error occurred.")
        }
        .accessibilityIdentifier("SearchMonitorDetailView")
    }

    private func monitorContent(_ monitor: SearchMonitor) -> some View {
        List {
            configSection(monitor)
            summariesSection
        }
        .listStyle(.insetGrouped)
    }

    private func configSection(_ monitor: SearchMonitor) -> some View {
        Section("Configuration") {
            LabeledContent("Status") {
                StatusBadge(status: monitor.status)
            }

            LabeledContent("Search Terms") {
                Text(monitor.searchTerms.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Interval") {
                Text("Every \(monitor.intervalHours) hour\(monitor.intervalHours == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Novelty Threshold") {
                Text(String(format: "%.1f", monitor.noveltyThreshold))
                    .foregroundStyle(.secondary)
            }

            if !monitor.description.isEmpty {
                LabeledContent("Description") {
                    Text(monitor.description)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var summariesSection: some View {
        Section("Summaries") {
            if viewModel.summaries.isEmpty {
                Text("No summaries yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.summaries) { summary in
                    NavigationLink {
                        SearchSummaryView(
                            summary: summary,
                            monitorId: viewModel.monitorId,
                            apiClient: apiClient
                        )
                    } label: {
                        SearchSummaryRow(summary: summary)
                    }
                    .accessibilityIdentifier("Summary_\(summary.id)")
                }
            }
        }
    }
}

/// Row view for a search summary in the detail list
struct SearchSummaryRow: View {
    let summary: SearchSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !summary.viewed {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }

                Text(formatTimestamp(summary.timestamp))
                    .font(.subheadline)
                    .fontWeight(!summary.viewed ? .bold : .medium)

                Spacer()

                if summary.significantUpdate {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                NoveltyIndicator(score: summary.noveltyScore)
            }

            Text(summary.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !summary.topics.isEmpty {
                Text(summary.topics.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatTimestamp(_ isoDate: String) -> String {
        let date = Self.isoFormatter.date(from: isoDate)
            ?? Self.isoFormatterNoFractional.date(from: isoDate)
        guard let date else { return isoDate }
        return Self.displayFormatter.string(from: date)
    }
}

/// Novelty score indicator
struct NoveltyIndicator: View {
    let score: Double

    var body: some View {
        Text(String(format: "%.0f%%", score * 100))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        if score >= 0.7 { return .red.opacity(0.15) }
        if score >= 0.4 { return .orange.opacity(0.15) }
        return .gray.opacity(0.15)
    }

    private var foregroundColor: Color {
        if score >= 0.7 { return .red }
        if score >= 0.4 { return .orange }
        return .secondary
    }
}
