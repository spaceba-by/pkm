import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class InsightsViewSnapshotTests: SnapshotTestCase {
    func test_summariesTab() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success(TestFixtures.sampleSummaries)
        assertDeviceSnapshotAfterTask(of: InsightsView(apiClient: mock))
    }
}
