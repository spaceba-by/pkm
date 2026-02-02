import SwiftUI

/// Settings screen with user info and sign out
struct SettingsView: View {
    let authService: any AuthServiceProtocol
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Text("Sign Out")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                    .accessibilityIdentifier("SignOutButton")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConfig.appVersion) (\(AppConfig.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func signOut() async {
        isSigningOut = true
        do {
            try await authService.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
        isSigningOut = false
    }
}

#Preview {
    SettingsView(authService: PreviewAuthService())
}

/// Preview-only mock auth service
private final class PreviewAuthService: AuthServiceProtocol, @unchecked Sendable {
    var isAuthenticated: Bool { false }

    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func getAccessToken() async throws -> String { "preview-token" }
}
