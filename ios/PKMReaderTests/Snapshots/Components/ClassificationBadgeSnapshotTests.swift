@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class ClassificationBadgeSnapshotTests: SnapshotTestCase {
    func test_allClassifications() {
        let view = VStack(spacing: 12) {
            ForEach(DocumentClassification.allCases, id: \.self) { classification in
                ClassificationBadge(classification: classification)
            }
        }
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 390, height: 250))
    }
}
