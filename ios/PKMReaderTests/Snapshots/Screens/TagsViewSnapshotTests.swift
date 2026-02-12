import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class TagsViewSnapshotTests: SnapshotTestCase {
    func test_loaded() {
        let mock = MockAPIClient()
        mock.listTagsResult = .success(TestFixtures.sampleTags)
        assertDeviceSnapshotAfterTask(of: TagsView(apiClient: mock))
    }

    func test_empty() {
        let mock = MockAPIClient()
        mock.listTagsResult = .success([])
        assertDeviceSnapshotAfterTask(of: TagsView(apiClient: mock))
    }
}
