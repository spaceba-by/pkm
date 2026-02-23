@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class SearchMonitorComponentSnapshotTests: SnapshotTestCase {
    // MARK: - NoveltyIndicator

    func test_noveltyIndicator_high() {
        let view = NoveltyIndicator(score: 0.85)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 100, height: 50))
    }

    func test_noveltyIndicator_medium() {
        let view = NoveltyIndicator(score: 0.5)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 100, height: 50))
    }

    func test_noveltyIndicator_low() {
        let view = NoveltyIndicator(score: 0.2)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 100, height: 50))
    }

    // MARK: - StatusBadge

    func test_statusBadge_active() {
        let view = StatusBadge(status: .active)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 120, height: 50))
    }

    func test_statusBadge_paused() {
        let view = StatusBadge(status: .paused)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 120, height: 50))
    }
}
