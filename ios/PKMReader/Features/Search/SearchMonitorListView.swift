import SwiftUI

/// List view showing all search monitors with status indicators
struct SearchMonitorListView: View {
    @StateObject private var viewModel: SearchMonitorListViewModel
    @State private var showingCreateForm = false
    @State private var monitorToDelete: SearchMonitor?

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
                EmptyStateView(
                    icon: "magnifyingglass.circle",
                    title: "No Search Monitors",
                    message: "Create a monitor to track topics over time"
                )

            case .error(let error):
                ErrorView(error: error) {
                    Task { await viewModel.loadMonitors() }
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
                    try? await viewModel.deleteMonitor(id: monitor.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { monitor in
            Text("Are you sure you want to delete \"\(monitor.name)\"? This cannot be undone.")
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

    private func formatRelativeDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoDate) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
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
