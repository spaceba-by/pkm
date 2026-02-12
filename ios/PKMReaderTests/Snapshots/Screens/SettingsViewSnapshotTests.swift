import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

final class SettingsViewSnapshotTests: SnapshotTestCase {
    func test_defaultState() {
        let mockAuth = MockAuthService()
        let view = SettingsView(authService: mockAuth)
        assertDeviceSnapshot(of: view)
    }
}
