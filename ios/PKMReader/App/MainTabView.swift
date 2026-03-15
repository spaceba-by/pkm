import SwiftUI

/// Main tab-based navigation after authentication
struct MainTabView: View {
    let apiClient: any APIClientProtocol
    let authService: any AuthServiceProtocol
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var notificationHandler: NotificationHandler = .shared
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

                InsightsView(apiClient: apiClient)
                    .tabItem {
                        Label("Insights", systemImage: "lightbulb.max")
                    }
                    .tag(1)
                    .badge(notificationHandler.unreadCount)

                ChatView(apiClient: apiClient)
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .tag(2)

                SettingsView(authService: authService)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)

                GraphView(apiClient: apiClient)
                    .tabItem {
                        Label("Graph", systemImage: "circle.hexagongrid")
                    }
                    .tag(4)
            }
        }
        .accessibilityIdentifier("MainTabView")
        .onChange(of: notificationHandler.pendingDeepLink) { _, deepLink in
            if let deepLink {
                handleDeepLink(deepLink)
                notificationHandler.clearDeepLink()
            }
        }
    }

    private func handleDeepLink(_ link: String) {
        if link.hasPrefix("/summaries") || link.hasPrefix("/reports") {
            selectedTab = 1
        } else if link.hasPrefix("/search") {
            selectedTab = 0
        }
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
