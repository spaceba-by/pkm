@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class LoginViewSnapshotTests: SnapshotTestCase {
    func test_defaultEmptyForm() {
        let mockAuth = MockAuthService()
        let view = LoginView(authService: mockAuth)
        assertDeviceSnapshot(of: view)
    }
}
