import Foundation

@MainActor
protocol SyncSchedulerProtocol {
    var isRunning: Bool { get }
    var isSyncInFlight: Bool { get }
    func start()
    func stop()
    func syncNow() async
}
