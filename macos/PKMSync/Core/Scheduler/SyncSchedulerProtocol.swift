import Foundation

@MainActor
protocol SyncSchedulerProtocol {
    var isRunning: Bool { get }
    func start()
    func stop()
    func syncNow() async
}
