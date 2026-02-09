import SwiftUI

/// Settings screen with user info, cache management, display preferences, and sign out
struct SettingsView: View {
    let authService: any AuthServiceProtocol
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false
    @State private var isClearingCache = false
    @State private var showCacheCleared = false
    @AppStorage("compactListMode")
    private var compactListMode = false
    @AppStorage("showDocumentPreviews")
    private var showDocumentPreviews = true

    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    Toggle("Compact List Mode", isOn: $compactListMode)
                        .accessibilityIdentifier("CompactListToggle")
                    Toggle("Show Document Previews", isOn: $showDocumentPreviews)
                        .accessibilityIdentifier("ShowPreviewsToggle")
                }

                Section("Storage") {
                    Button {
                        Task { await clearCache() }
                    } label: {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                            } else if showCacheCleared {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(isClearingCache)
                    .accessibilityIdentifier("ClearCacheButton")
                }

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

    private func clearCache() async {
        isClearingCache = true
        do {
            let cacheService = try DocumentCacheService()
            cacheService.clearCache()
            showCacheCleared = true
            try? await Task.sleep(for: .seconds(2))
            showCacheCleared = false
        } catch {
            print("Cache clear error: \(error)")
        }
        isClearingCache = false
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
