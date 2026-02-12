import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class SearchViewSnapshotTests: SnapshotTestCase {
    func test_idle() {
        let mock = MockAPIClient()
        let view = SearchView(apiClient: mock)
        assertDeviceSnapshot(of: view)
    }
}
