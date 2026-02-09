import SwiftUI

/// Settings screen with user info, cache management, display preferences, and sign out
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @AppStorage("compactListMode")
    private var compactListMode = false
    @AppStorage("showDocumentPreviews")
    private var showDocumentPreviews = true
    @State private var showingSignOutAlert = false

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }

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
                        Task { await viewModel.clearCache() }
                    } label: {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            if viewModel.isClearingCache {
                                ProgressView()
                            } else if viewModel.showCacheCleared {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(viewModel.isClearingCache)
                    .accessibilityIdentifier("ClearCacheButton")
                }

                Section("Account") {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Text("Sign Out")
                            Spacer()
                            if viewModel.isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isSigningOut)
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
                    Task { await viewModel.signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
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
