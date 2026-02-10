import Foundation

/// View model for the Settings screen
@MainActor
final class SettingsViewModel: ObservableObject {
    /// Current state for sign out operation
    @Published private(set) var isSigningOut = false

    /// Current state for cache clear operation
    @Published private(set) var isClearingCache = false

    /// Whether to show cache cleared confirmation
    @Published private(set) var showCacheCleared = false

    private let authService: any AuthServiceProtocol
    private let clearCacheHandler: () throws -> Void
    private let confirmationDuration: Duration

    init(
        authService: any AuthServiceProtocol,
        clearCacheHandler: (() throws -> Void)? = nil,
        confirmationDuration: Duration = .seconds(2)
    ) {
        self.authService = authService
        self.clearCacheHandler = clearCacheHandler ?? {
            let cacheService = try DocumentCacheService()
            cacheService.clearCache()
        }
        self.confirmationDuration = confirmationDuration
    }

    /// Sign out the current user
    func signOut() async {
        isSigningOut = true
        do {
            try await authService.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
        isSigningOut = false
    }

    /// Clear the document cache
    func clearCache() async {
        isClearingCache = true
        do {
            try clearCacheHandler()
            showCacheCleared = true
            try? await Task.sleep(for: confirmationDuration)
            showCacheCleared = false
        } catch {
            print("Cache clear error: \(error)")
        }
        isClearingCache = false
    }
}
