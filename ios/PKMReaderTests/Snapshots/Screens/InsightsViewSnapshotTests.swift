import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class InsightsViewSnapshotTests: SnapshotTestCase {
    override var isRecordMode: Bool { false }

    func test_calendarWithData() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mock.listReportsResult = .success(TestFixtures.sampleReports)
        assertDeviceSnapshotAfterTask(of: InsightsView(apiClient: mock))
    }

    func test_calendarEmpty() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success([])
        mock.listReportsResult = .success([])
        assertDeviceSnapshotAfterTask(of: InsightsView(apiClient: mock))
    }
}
