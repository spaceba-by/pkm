@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class TaskListViewSnapshotTests: SnapshotTestCase {
    func test_loaded() {
        let mock = MockAPIClient()
        mock.listTasksResult = .success(TestFixtures.sampleTaskListResponse)
        mock.getTaskStatsResult = .success(TestFixtures.sampleTaskStats)
        assertDeviceSnapshotAfterTask(of: TaskListView(apiClient: mock))
    }

    func test_empty() {
        let mock = MockAPIClient()
        mock.listTasksResult = .success(
            TaskListResponse(tasks: [], count: 0, nextCursor: nil)
        )
        mock.getTaskStatsResult = .success(
            TaskStatsResponse(open: 0, completed: 0, total: 0)
        )
        assertDeviceSnapshotAfterTask(of: TaskListView(apiClient: mock))
    }

    func test_error() {
        let mock = MockAPIClient()
        mock.listTasksResult = .failure(APIError.networkError)
        assertDeviceSnapshotAfterTask(of: TaskListView(apiClient: mock))
    }
}
