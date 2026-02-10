import Foundation
import Network

/// Monitors network connectivity using NWPathMonitor
@MainActor
final class NetworkMonitor: ObservableObject {
    /// Whether the device currently has network connectivity
    @Published private(set) var isConnected = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    /// Shared singleton instance
    static let shared = NetworkMonitor()

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    /// Start monitoring network changes
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    /// Stop monitoring network changes
    func stop() {
        monitor.cancel()
    }
}
