import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class EmptyStateViewSnapshotTests: SnapshotTestCase {
    func test_noDocuments() {
        let view = EmptyStateView(
            icon: "doc.text",
            title: "No Documents",
            message: "Your vault is empty"
        )
        assertDeviceSnapshot(of: view)
    }

    func test_noSearchResults() {
        let view = EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No documents match your search"
        )
        assertDeviceSnapshot(of: view)
    }
}
