@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class DispatchListViewSnapshotTests: SnapshotTestCase {
    func test_loaded() {
        let mock = MockAPIClient()
        mock.listJobsResult = .success(TestFixtures.sampleJobListResponse)
        assertDeviceSnapshotAfterTask(of: DispatchListView(apiClient: mock))
    }

    func test_empty() {
        let mock = MockAPIClient()
        mock.listJobsResult = .success(
            JobListResponse(jobs: [], count: 0, nextCursor: nil)
        )
        assertDeviceSnapshotAfterTask(of: DispatchListView(apiClient: mock))
    }

    func test_error() {
        let mock = MockAPIClient()
        mock.listJobsResult = .failure(APIError.networkError)
        assertDeviceSnapshotAfterTask(of: DispatchListView(apiClient: mock))
    }
}
