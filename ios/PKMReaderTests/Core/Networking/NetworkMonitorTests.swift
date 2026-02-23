import Network
@testable import PKMReader
import XCTest

@MainActor
final class NetworkMonitorTests: XCTestCase {
    // MARK: - Initial State

    func test_initialState_isConnected() {
        let monitor = NetworkMonitor()
        XCTAssertTrue(monitor.isConnected)
    }
}
