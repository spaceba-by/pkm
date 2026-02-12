import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class DocumentListViewSnapshotTests: SnapshotTestCase {
    func test_loaded() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .success(TestFixtures.sampleDocumentListResponse)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock))
    }

    func test_empty() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .success(TestFixtures.emptyDocumentListResponse)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock))
    }

    func test_error() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .failure(APIError.networkError)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock))
    }
}
