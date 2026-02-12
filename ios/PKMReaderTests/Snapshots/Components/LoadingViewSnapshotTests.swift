import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class LoadingViewSnapshotTests: SnapshotTestCase {
    func test_withMessage() {
        let view = LoadingView(message: "Loading documents...")
        assertDeviceSnapshot(of: view)
    }

    func test_withoutMessage() {
        let view = LoadingView()
        assertDeviceSnapshot(of: view)
    }
}
