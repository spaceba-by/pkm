import SwiftUI

/// Main tab-based navigation after authentication
struct MainTabView: View {
    let apiClient: any APIClientProtocol
    let authService: any AuthServiceProtocol
    @State private var selectedTab = 0

    var body: some View {
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
        .accessibilityIdentifier("MainTabView")
    }
}

#Preview {
    MainTabView(
        apiClient: APIClient(authService: AuthService.shared),
        authService: AuthService.shared
    )
}
