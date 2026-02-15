import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class ErrorViewSnapshotTests: SnapshotTestCase {
    func test_networkError_withRetry() {
        let view = ErrorView(error: APIError.networkError) {}
        assertDeviceSnapshot(of: view)
    }

    func test_genericError_withRetry() {
        let view = ErrorView(error: APIError.decodingError) {}
        assertDeviceSnapshot(of: view)
    }

    func test_genericError_noRetry() {
        let view = ErrorView(error: APIError.invalidResponse)
        assertDeviceSnapshot(of: view)
    }
}
