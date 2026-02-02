import SwiftUI

/// Main tab-based navigation after authentication
struct MainTabView: View {
    let authService: AuthService
    @State private var selectedTab = 0

    private var apiClient: APIClient {
        APIClient(authService: authService)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DocumentListView(apiClient: apiClient)
                .tabItem {
                    Label("Documents", systemImage: "doc.text")
                }
                .tag(0)

            SettingsView(authService: authService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .accessibilityIdentifier("MainTabView")
    }
}

#Preview {
    MainTabView(authService: AuthService.shared)
}
