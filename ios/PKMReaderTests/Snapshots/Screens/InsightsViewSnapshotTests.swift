@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class InsightsViewSnapshotTests: SnapshotTestCase {
    /// Fixed date (2026-02-17 noon UTC) and UTC calendar so the "today"
    /// highlight is deterministic regardless of the machine's timezone.
    private let snapshotToday = Date(timeIntervalSince1970: 1_771_329_600)
    private let snapshotCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = 1 // Sunday
        return cal
    }()

    func test_calendarWithData() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mock.listReportsResult = .success(TestFixtures.sampleReports)
        assertDeviceSnapshotAfterTask(of: InsightsView(
            apiClient: mock,
            calendar: snapshotCalendar,
            today: snapshotToday
        ))
    }

    func test_calendarEmpty() {
        let mock = MockAPIClient()
        mock.listSummariesResult = .success([])
        mock.listReportsResult = .success([])
        assertDeviceSnapshotAfterTask(of: InsightsView(
            apiClient: mock,
            calendar: snapshotCalendar,
            today: snapshotToday
        ))
    }
}
