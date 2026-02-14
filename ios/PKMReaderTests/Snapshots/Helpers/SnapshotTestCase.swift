import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import PKMReader

// MARK: - iPhone 17 Device Configuration

extension ViewImageConfig {
    /// iPhone 17 portrait configuration (393×852, Dynamic Island safe area)
    static let iPhone17 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 393, height: 852),
        traits: UITraitCollection(traitsFrom: [
            .init(forceTouchCapability: .unavailable),
            .init(layoutDirection: .leftToRight),
            .init(preferredContentSizeCategory: .medium),
            .init(userInterfaceIdiom: .phone),
            .init(horizontalSizeClass: .compact),
            .init(verticalSizeClass: .regular),
        ])
    )
}

// MARK: - Snapshot Test Base Class

/// Base class for snapshot tests with shared configuration
@MainActor
class SnapshotTestCase: XCTestCase {
    /// Set to `true` to record new reference images, then flip back to `false`
    var isRecordMode: Bool { false }

    /// Precision tolerance for pixel matching (0.0–1.0)
    /// Allows minor rendering differences across environments
    var snapshotPrecision: Float { 0.99 }

    /// Perceptual precision tolerance (0.0–1.0)
    /// 98-99% mimics the precision of the human eye
    var snapshotPerceptualPrecision: Float { 0.98 }

    override func invokeTest() {
        withSnapshotTesting(record: isRecordMode ? .all : .never) {
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
            as: .image(
                on: .iPhone17,
                precision: snapshotPrecision,
                perceptualPrecision: snapshotPerceptualPrecision
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Assert a SwiftUI view matches its snapshot using a fixed-size layout
    func assertComponentSnapshot<V: View>(
        of view: V,
        size: CGSize = CGSize(width: 393, height: 200),
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
            as: .image(
                precision: snapshotPrecision,
                perceptualPrecision: snapshotPerceptualPrecision
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Assert a SwiftUI view matches its snapshot after allowing async `.task` modifiers to settle
    func assertDeviceSnapshotAfterTask<V: View>(
        of view: V,
        settleDuration: TimeInterval = 1.0,
        named name: String? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = .light

        // Place the controller in a window so `.task` fires
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 393, height: 852)))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        // Spin the run loop to let `.task` modifiers fire and SwiftUI update
        // RunLoop.run is more reliable than DispatchQueue.main.asyncAfter on CI
        RunLoop.current.run(until: Date(timeIntervalSinceNow: settleDuration))

        assertSnapshot(
            of: controller,
            as: .image(
                on: .iPhone17,
                precision: snapshotPrecision,
                perceptualPrecision: snapshotPerceptualPrecision
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )

        window.rootViewController = nil
        window.isHidden = true
    }
}
