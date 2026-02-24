import Foundation
import UserNotifications
import UIKit

/// Protocol for notification service to enable testing
protocol NotificationServiceProtocol: Sendable {
    /// Request notification permission and register for remote notifications
    func requestAuthorization() async throws -> Bool

    /// Whether the user has granted notification permission
    var isAuthorized: Bool { get async }
}

/// Manages APNs registration and device token lifecycle
@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var deviceToken: String?
    @Published private(set) var isRegistered = false

    private var apiClient: (any APIClientProtocol)?
    private var registeredDeviceId: String?

    override private init() {
        super.init()
    }

    /// Internal init for testing
    init(apiClient: any APIClientProtocol) {
        super.init()
        self.apiClient = apiClient
    }

    /// Set the API client for device token registration
    func configure(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    /// Called when APNs returns a device token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        Task {
            await registerDeviceTokenWithBackend(tokenString)
        }
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        self.deviceToken = nil
        self.isRegistered = false
    }

    private func registerDeviceTokenWithBackend(_ token: String) async {
        guard let apiClient else { return }

        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let request = DeviceRegistrationRequest(
            deviceToken: token,
            deviceId: deviceId,
            platform: "ios",
            appVersion: appVersion
        )

        do {
            _ = try await apiClient.registerDevice(request: request)
            registeredDeviceId = deviceId
            isRegistered = true
        } catch {
            print("Failed to register device token with backend: \(error.localizedDescription)")
            isRegistered = false
        }
    }

    /// Unregister the current device from push notifications
    func unregisterDevice() async {
        guard let apiClient, let deviceId = registeredDeviceId else { return }

        do {
            try await apiClient.unregisterDevice(deviceId: deviceId)
            isRegistered = false
            deviceToken = nil
            registeredDeviceId = nil
        } catch {
            print("Failed to unregister device: \(error.localizedDescription)")
        }
    }
}
