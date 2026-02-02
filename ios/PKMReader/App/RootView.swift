import SwiftUI

/// Root view that handles auth state and navigation
struct RootView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isInitialized = false

    var body: some View {
        Group {
            if !isInitialized {
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
            do {
                try await authService.configure()
                isInitialized = true
            } catch {
                print("Failed to initialize auth: \(error)")
                isInitialized = true
            }
        }
    }
}

#Preview {
    RootView()
}
