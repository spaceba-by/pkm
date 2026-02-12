import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

/// Base class for snapshot tests with shared configuration
@MainActor
class SnapshotTestCase: XCTestCase {
    /// Set to `true` to record new reference images, then flip back to `false`
    var isRecordMode: Bool { false }

    override func invokeTest() {
        withSnapshotTesting(record: isRecordMode ? .all : .missing) {
            super.invokeTest()
        }
    }

    /// Assert a SwiftUI view matches its snapshot using the device layout
    func assertDeviceSnapshot<V: View>(
        of view: V,
        named name: String? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light

        assertSnapshot(
            of: controller,
            as: .image(on: .iPhone13),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Assert a SwiftUI view matches its snapshot using a fixed-size layout
    func assertComponentSnapshot<V: View>(
        of view: V,
        size: CGSize = CGSize(width: 390, height: 200),
        named name: String? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light
        controller.view.frame = CGRect(origin: .zero, size: size)

        assertSnapshot(
            of: controller,
            as: .image(size: size),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Assert a SwiftUI view matches its snapshot after allowing async `.task` modifiers to settle
    func assertDeviceSnapshotAfterTask<V: View>(
        of view: V,
        named name: String? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light

        // Place the controller in a window so `.task` fires
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()

        // Allow async `.task` to complete and SwiftUI to update
        let settled = expectation(description: "UI settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2)

        assertSnapshot(
            of: controller,
            as: .image(on: .iPhone13),
            named: name,
            file: file,
            testName: testName,
            line: line
        )

        window.isHidden = true
    }
}
