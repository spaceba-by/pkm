import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class InsightsViewSnapshotTests: SnapshotTestCase {
    override var isRecordMode: Bool { false }

    /// Fixed date matching the reference snapshot (2026-02-18) so the
    /// "today" highlight is always on the same day regardless of when tests run.
    private let snapshotToday = Date(timeIntervalSince1970: 1_771_286_400)

    func test_calendarWithData() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mock.listReportsResult = .success(TestFixtures.sampleReports)
        assertDeviceSnapshotAfterTask(of: InsightsView(apiClient: mock, today: snapshotToday))
    }

    func test_calendarEmpty() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success([])
        mock.listReportsResult = .success([])
        assertDeviceSnapshotAfterTask(of: InsightsView(apiClient: mock, today: snapshotToday))
    }
}
