import Foundation
import UserNotifications

/// Handles received push notifications and deep link routing
@MainActor
final class NotificationHandler: NSObject, ObservableObject {
    static let shared = NotificationHandler()

    /// Deep link path to navigate to when a notification is tapped
    @Published var pendingDeepLink: String?

    /// Unread notification count for badge display
    @Published private(set) var unreadCount: Int = 0

    private var apiClient: (any APIClientProtocol)?

    // swiftlint:disable:next modifier_order
    private override init() {
        super.init()
    }

    /// Internal init for testing
    init(apiClient: any APIClientProtocol) {
        super.init()
        self.apiClient = apiClient
    }

    /// Set the API client for notification operations
    func configure(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Process a notification payload received while app is in foreground or background
    func handleNotification(userInfo: [AnyHashable: Any]) {
        if let deepLink = userInfo["deepLink"] as? String {
            pendingDeepLink = deepLink
        }
    }

    /// Load unread notification count from backend
    func refreshUnreadCount() async {
        guard let apiClient else { return }
        do {
            let response = try await apiClient.listNotifications()
            unreadCount = response.notifications.count(where: { !$0.read })
        } catch {
            // Silently fail — badge count is non-critical
        }
    }

    /// Mark a notification as read
    func markAsRead(notificationId: String) async {
        guard let apiClient else { return }
        do {
            try await apiClient.markNotificationRead(id: notificationId)
            if unreadCount > 0 {
                unreadCount -= 1
            }
        } catch {
            // Silently fail
        }
    }

    /// Set a deep link from a notification tap (called from nonisolated delegate)
    func setDeepLink(_ deepLink: String) {
        pendingDeepLink = deepLink
    }

    /// Clear the pending deep link after navigation
    func clearDeepLink() {
        pendingDeepLink = nil
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationHandler: @preconcurrency UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let deepLink = response.notification.request.content.userInfo["deepLink"] as? String
        if let deepLink {
            await setDeepLink(deepLink)
        }
    }
}
