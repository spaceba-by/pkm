@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class SearchSummaryViewSnapshotTests: SnapshotTestCase {
    func test_fullSummary() {
        let summary = SearchSummary(
            timestamp: "2026-02-20T10:00:00Z",
            summary: "Significant developments in AI research with new breakthroughs in reasoning capabilities.",
            topics: ["AI", "reasoning", "language models", "benchmarks"],
            noveltyScore: 0.85,
            significantUpdate: true,
            newItems: [
                "New paper on advanced reasoning",
                "Novel architecture proposed",
            ],
            changedItems: [
                "Updated benchmark scores",
                "Revised training methodology",
            ],
            removedItems: [
                "Deprecated evaluation framework",
            ],
            analysis: """
            This update represents a major shift in the field with several key papers \
            introducing new approaches to reasoning in language models.
            """
        )

        let view = NavigationStack {
            SearchSummaryView(summary: summary)
        }
        assertDeviceSnapshot(of: view)
    }

    func test_minimalSummary() {
        let summary = SearchSummary(
            timestamp: "2026-02-20T10:00:00Z",
            summary: "No significant changes detected.",
            topics: [],
            noveltyScore: 0.1,
            significantUpdate: false,
            newItems: [],
            changedItems: [],
            removedItems: [],
            analysis: nil
        )

        let view = NavigationStack {
            SearchSummaryView(summary: summary)
        }
        assertDeviceSnapshot(of: view)
    }

    func test_summaryWithOnlyNewItems() {
        let summary = SearchSummary(
            timestamp: "2026-02-20T10:00:00Z",
            summary: "Several new items discovered.",
            topics: ["tech"],
            noveltyScore: 0.6,
            significantUpdate: false,
            newItems: ["Item 1", "Item 2", "Item 3"],
            changedItems: [],
            removedItems: [],
            analysis: "Brief analysis."
        )

        let view = NavigationStack {
            SearchSummaryView(summary: summary)
        }
        assertDeviceSnapshot(of: view)
    }
}
