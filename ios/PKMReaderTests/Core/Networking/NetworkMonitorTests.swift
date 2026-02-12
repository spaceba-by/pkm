import XCTest
import Network
@testable import PKMReader

@MainActor
final class NetworkMonitorTests: XCTestCase {
    // MARK: - Initial State

    func test_initialState_isConnected() {
        let monitor = NetworkMonitor()
        XCTAssertTrue(monitor.isConnected)
    }
}
