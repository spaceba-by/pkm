@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class DocumentListViewSnapshotTests: SnapshotTestCase {
    /// Lower precision to accommodate `.searchable` rendering variance
    override var snapshotPrecision: Float {
        0.97
    }

    override var snapshotPerceptualPrecision: Float {
        0.95
    }

    /// Longer settle time for DocumentListView — the NavigationStack + List
    /// rendering path needs more RunLoop iterations in slow CI environments.
    private let settle: TimeInterval = 3.0

    func test_loaded() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .success(TestFixtures.sampleDocumentListResponse)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock), settleDuration: settle)
    }

    func test_empty() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .success(TestFixtures.emptyDocumentListResponse)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock), settleDuration: settle)
    }

    func test_error() {
        let mock = MockAPIClient()
        mock.listDocumentsResult = .failure(APIError.networkError)
        assertDeviceSnapshotAfterTask(of: DocumentListView(apiClient: mock), settleDuration: settle)
    }
}
