@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class TagChipSnapshotTests: SnapshotTestCase {
    func test_tagChips() {
        let view = HStack(spacing: 8) {
            TagChip(tag: "meeting")
            TagChip(tag: "project")
            TagChip(tag: "idea")
        }
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 390, height: 60))
    }
}
