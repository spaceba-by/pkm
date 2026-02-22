import SwiftUI

/// List view showing all search monitors with status indicators
struct SearchMonitorListView: View {
    @StateObject private var viewModel: SearchMonitorListViewModel
    @State private var showingCreateForm = false
    @State private var monitorToDelete: SearchMonitor?
    @State private var deleteError: Error?

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SearchMonitorListViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading monitors...")

            case .loaded:
                monitorList

            case .empty:
                ScrollView {
                    EmptyStateView(
                        icon: "magnifyingglass.circle",
                        title: "No Search Monitors",
                        message: "Create a monitor to track topics over time"
                    )
                }

            case .error(let error):
                ScrollView {
                    ErrorView(error: error) {
                        Task { await viewModel.loadMonitors() }
                    }
                }
            }
        }
        .navigationTitle("Search Monitors")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("CreateMonitorButton")
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            NavigationStack {
                SearchMonitorFormView(apiClient: viewModel.apiClient) { request in
                    try await viewModel.createMonitor(request: request)
                }
            }
        }
        .alert(
            "Delete Monitor",
            isPresented: Binding(
                get: { monitorToDelete != nil },
                set: { if !$0 { monitorToDelete = nil } }
            ),
            presenting: monitorToDelete
        ) { monitor in
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteMonitor(id: monitor.id)
                    } catch {
                        deleteError = error
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { monitor in
            Text("Are you sure you want to delete \"\(monitor.name)\"? This cannot be undone.")
        }
        .alert(
            "Delete Failed",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError?.localizedDescription ?? "An unknown error occurred.")
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadMonitors()
        }
        .accessibilityIdentifier("SearchMonitorListView")
    }

    private var monitorList: some View {
        List {
            ForEach(viewModel.monitors) { monitor in
                NavigationLink(value: monitor) {
                    SearchMonitorRow(monitor: monitor)
                }
                .accessibilityIdentifier("Monitor_\(monitor.id)")
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    monitorToDelete = viewModel.monitors[index]
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: SearchMonitor.self) { monitor in
            SearchMonitorDetailView(monitorId: monitor.id, apiClient: viewModel.apiClient)
        }
    }
}

/// Row view for a single search monitor in the list
struct SearchMonitorRow: View {
    let monitor: SearchMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(monitor.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: monitor.status)
            }

            Text(monitor.searchTerms.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Label("Every \(monitor.intervalHours)h", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let lastExecuted = monitor.lastExecuted {
                    Label(formatRelativeDate(lastExecuted), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func formatRelativeDate(_ isoDate: String) -> String {
        if let date = Self.isoFormatter.date(from: isoDate) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        if let date = Self.isoFormatterNoFractional.date(from: isoDate) {
            return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return isoDate
    }
}

/// Status badge showing active/paused state
struct StatusBadge: View {
    let status: SearchMonitorStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .active: .green.opacity(0.15)
        case .paused: .orange.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .active: .green
        case .paused: .orange
        }
    }
}
