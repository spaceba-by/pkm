import SwiftUI

/// Root view that handles auth state and navigation
struct RootView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isInitialized = false
    @State private var configurationError: Error?

    /// Check if app is launched in logged-out mode for UI testing
    private var isLoggedOutTestMode: Bool {
        #if DEBUG
            return CommandLine.arguments.contains("--logged-out")
        #else
            return false
        #endif
    }

    /// Check if app is launched with mock API for UI testing
    private var isMockAPIMode: Bool {
        #if DEBUG
            return CommandLine.arguments.contains("--mock-api")
        #else
            return false
        #endif
    }

    var body: some View {
        Group {
            #if DEBUG
                if isMockAPIMode {
                    // UI testing mode: show main tab with mock data, skip auth
                    MainTabView(
                        apiClient: UITestAPIClient(),
                        authService: UITestAuthService(),
                        networkMonitor: networkMonitor
                    )
                } else if isLoggedOutTestMode {
                    // UI testing mode: show login screen directly
                    LoginView(authService: authService)
                } else {
                    authenticatedContent
                }
            #else
                authenticatedContent
            #endif
        }
        .task {
            // Start network monitoring
            networkMonitor.start()

            // Skip auth initialization in test modes
            guard !isLoggedOutTestMode, !isMockAPIMode else { return }

            do {
                try await authService.configure()
                isInitialized = true
            } catch {
                configurationError = error
                isInitialized = true
            }
        }
    }

    @ViewBuilder private var authenticatedContent: some View {
        if let error = configurationError {
            ErrorView(error: error, retryAction: nil)
        } else if !isInitialized {
            LoadingView(message: "Initializing...")
        } else {
            switch authService.authState {
            case .unknown:
                LoadingView(message: "Checking authentication...")

            case .signedOut:
                LoginView(authService: authService)

            case .signedIn:
                MainTabView(
                    apiClient: APIClient(authService: authService, networkMonitor: networkMonitor),
                    authService: authService,
                    networkMonitor: networkMonitor
                )
            }
        }
    }
}

#Preview {
    RootView()
}
