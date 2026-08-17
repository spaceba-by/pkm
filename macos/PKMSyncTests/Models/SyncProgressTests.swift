@testable import PKMSync
import XCTest

final class SyncProgressTests: XCTestCase {
    func testFractionPrefersBytes() {
        var progress = SyncProgress()
        progress.bytesTransferred = 512
        progress.bytesTotal = 1024
        progress.filesDone = 1
        progress.filesTotal = 100

        XCTAssertEqual(progress.fractionCompleted ?? 0, 0.5, accuracy: 0.0001)
    }

    func testFractionFallsBackToFileCounts() {
        var progress = SyncProgress()
        progress.filesDone = 1
        progress.filesTotal = 4

        XCTAssertEqual(progress.fractionCompleted ?? 0, 0.25, accuracy: 0.0001)
    }

    func testFractionIsNilBeforeAnyTotalIsKnown() {
        XCTAssertNil(
            SyncProgress().fractionCompleted,
            "An unknown total must read as indeterminate, not as 0%"
        )
    }

    func testFractionIsClampedToOne() {
        var progress = SyncProgress()
        progress.bytesTransferred = 2048
        progress.bytesTotal = 1024

        XCTAssertEqual(progress.fractionCompleted, 1)
    }

    func testStatsLineIsNilWhenNothingIsKnown() {
        XCTAssertNil(SyncProgress().statsLine)
    }

    func testStatsLineCombinesKnownFields() throws {
        var progress = SyncProgress()
        progress.filesDone = 2
        progress.filesTotal = 3
        progress.bytesTransferred = 1_048_576
        progress.bytesTotal = 4_194_304
        progress.speed = "2.0 MiB/s"
        progress.eta = "16s"

        let stats = try XCTUnwrap(progress.statsLine)

        XCTAssertTrue(stats.contains("2/3 files"), stats)
        XCTAssertTrue(stats.contains("2.0 MiB/s"), stats)
        XCTAssertTrue(stats.contains("ETA 16s"), stats)
    }

    func testStatsLineShowsListedCountWhileListing() {
        var progress = SyncProgress()
        progress.objectsListed = 42

        XCTAssertEqual(progress.statsLine, "42 listed")
    }

    func testStatsLineOmitsIdleSpeed() {
        var progress = SyncProgress()
        progress.objectsListed = 5
        progress.speed = "0 B/s"

        XCTAssertEqual(progress.statsLine, "5 listed")
    }

    func testPhaseLabelsUseFriendlySideNames() {
        XCTAssertEqual(SyncPhase.checkingDiffs(path: "Path1").label, "Checking vault for changes")
        XCTAssertEqual(SyncPhase.checkingDiffs(path: "Path2").label, "Checking cloud for changes")
    }

    func testStatusExposesProgressAndSyncingFlag() {
        var progress = SyncProgress()
        progress.phase = .applyingChanges

        let status = SyncStatus.syncing(progress)

        XCTAssertTrue(status.isSyncing)
        XCTAssertEqual(status.progress?.phase, .applyingChanges)
        XCTAssertEqual(status.label, "Transferring files")

        XCTAssertFalse(SyncStatus.idle.isSyncing)
        XCTAssertNil(SyncStatus.idle.progress)
    }
}
