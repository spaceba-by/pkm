import SwiftUI

/// Root view that handles auth state and navigation
struct RootView: View {
    @StateObject private var authService = AuthService.shared
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

    var body: some View {
        Group {
            if isLoggedOutTestMode {
                // UI testing mode: show login screen directly
                LoginView(authService: authService)
            } else if let error = configurationError {
                ErrorView(error: error)
            } else if !isInitialized {
                LoadingView(message: "Initializing...")
            } else {
                switch authService.authState {
                case .unknown:
                    LoadingView(message: "Checking authentication...")

                case .signedOut:
                    LoginView(authService: authService)

                case .signedIn:
                    MainTabView(authService: authService)
                }
            }
        }
        .task {
            // Skip Amplify configuration in logged-out test mode
            guard !isLoggedOutTestMode else { return }

            do {
                try await authService.configure()
                isInitialized = true
            } catch {
                print("Failed to initialize auth: \(error)")
                configurationError = error
                isInitialized = true
            }
        }
    }
}

#Preview {
    RootView()
}
