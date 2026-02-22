import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

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

    // MARK: - SearchSummaryRow

    func test_summaryRow_significantUpdate() {
        let summary = SearchSummary(
            timestamp: "2026-02-20T10:00:00Z",
            summary: "Major findings in AI research with several breakthroughs in reasoning.",
            topics: ["AI", "reasoning", "benchmarks"],
            noveltyScore: 0.85,
            significantUpdate: true,
            newItems: ["New paper"],
            changedItems: [],
            removedItems: [],
            analysis: nil
        )
        let view = SearchSummaryRow(summary: summary)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 393, height: 100))
    }

    func test_summaryRow_normalUpdate() {
        let summary = SearchSummary(
            timestamp: "2026-02-20T10:00:00Z",
            summary: "Minor updates with no significant changes detected.",
            topics: [],
            noveltyScore: 0.2,
            significantUpdate: false,
            newItems: [],
            changedItems: [],
            removedItems: [],
            analysis: nil
        )
        let view = SearchSummaryRow(summary: summary)
            .padding()
        assertComponentSnapshot(of: view, size: CGSize(width: 393, height: 80))
    }
}
