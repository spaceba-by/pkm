import SwiftUI

/// Main tab-based navigation after authentication
struct MainTabView: View {
    let apiClient: any APIClientProtocol
    let authService: any AuthServiceProtocol
    @ObservedObject var networkMonitor: NetworkMonitor
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                OfflineBanner()
            }

            TabView(selection: $selectedTab) {
                DocumentListView(apiClient: apiClient)
                    .tabItem {
                        Label("Documents", systemImage: "doc.text")
                    }
                    .tag(0)

                SearchView(apiClient: apiClient)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                TagsView(apiClient: apiClient)
                    .tabItem {
                        Label("Tags", systemImage: "tag")
                    }
                    .tag(2)

                InsightsView(apiClient: apiClient)
                    .tabItem {
                        Label("Insights", systemImage: "lightbulb.max")
                    }
                    .tag(3)

                SettingsView(authService: authService)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }
        }
        .accessibilityIdentifier("MainTabView")
    }
}

/// Banner shown when the device is offline
private struct OfflineBanner: View {
    @ScaledMetric(relativeTo: .footnote)
    private var verticalPadding: CGFloat = 6

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.footnote)
            Text("No internet connection")
                .font(.footnote)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .background(Color(.systemOrange).opacity(0.9))
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No internet connection")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("OfflineBanner")
    }
}

#Preview {
    MainTabView(
        apiClient: APIClient(authService: AuthService.shared, networkMonitor: NetworkMonitor.shared),
        authService: AuthService.shared,
        networkMonitor: NetworkMonitor.shared
    )
}
