@testable import PKMSync
import XCTest

/// Fixtures are verbatim lines captured from `rclone v1.75.0` running
/// `bisync --verbose --stats 1s`.
final class RcloneProgressParserTests: XCTestCase {
    private var sut: RcloneProgressParser!

    override func setUp() {
        super.setUp()
        sut = RcloneProgressParser()
    }

    // MARK: - Phases

    func testParsesBuildingListingsPhase() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:28 INFO  : Building Path1 and Path2 listings"
        )

        XCTAssertEqual(progress?.phase, .buildingListings)
    }

    func testParsesCheckingDiffsPhaseWithPath() {
        let progress = sut.consume(line: "2026/08/12 11:37:28 INFO  : Path2 checking for diffs")

        XCTAssertEqual(progress?.phase, .checkingDiffs(path: "Path2"))
    }

    func testParsesApplyingChangesPhase() {
        let progress = sut.consume(line: "2026/08/12 11:37:28 INFO  : Applying changes")

        XCTAssertEqual(progress?.phase, .applyingChanges)
    }

    func testParsesResyncCopyingAsApplyingChanges() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:15 INFO  : Copying Path2 files to Path1"
        )

        XCTAssertEqual(progress?.phase, .applyingChanges)
    }

    func testParsesUpdatingListingsPhaseForBothVariants() {
        XCTAssertEqual(
            sut.consume(line: "2026/08/12 11:37:28 INFO  : Updating listings")?.phase,
            .updatingListings
        )
        XCTAssertEqual(
            sut.consume(line: "2026/08/12 11:37:15 INFO  : Resync updating listings")?.phase,
            .updatingListings
        )
    }

    func testParsesValidatingPhase() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:28 INFO  : Validating listings for Path1 \"/vault/\" vs Path2 \"s3:/\""
        )

        XCTAssertEqual(progress?.phase, .validating)
    }

    func testParsesFinishingPhase() {
        let progress = sut.consume(line: "2026/08/12 11:37:28 INFO  : Bisync successful")

        XCTAssertEqual(progress?.phase, .finishing)
    }

    func testPhaseChangeClearsStaleObject() {
        _ = sut.consume(line: "2026/08/12 11:37:28 INFO  : file1.md: Copied (new)")
        let progress = sut.consume(line: "2026/08/12 11:37:28 INFO  : Updating listings")

        XCTAssertNil(progress?.currentObject)
    }

    // MARK: - Current object

    func testParsesCompletedObject() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:15 INFO  : sub/deep.md: Copied (server-side copy)"
        )

        XCTAssertEqual(progress?.currentObject, "sub/deep.md")
    }

    func testParsesDeletedAndModtimeObjects() {
        XCTAssertEqual(
            sut.consume(line: "2026/08/12 11:37:15 INFO  : old.md: Deleted")?.currentObject,
            "old.md"
        )
        XCTAssertEqual(
            sut.consume(
                line: "2026/08/12 11:37:15 INFO  : a.md: Updated modification time"
            )?.currentObject,
            "a.md"
        )
    }

    func testIgnoresDirectoryBookkeeping() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:15 INFO  : sub: Set directory modification time (using DirSetModTime)"
        )

        XCTAssertNil(progress)
    }

    func testParsesObjectFromDiffScanLine() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:28 INFO  : - Path1    File is new               - big/blob.bin"
        )

        XCTAssertEqual(progress?.currentObject, "big/blob.bin")
    }

    func testIgnoresQueueLinesThatNameASideNotAFile() {
        // "Do queued copies to - Path1" would otherwise surface "Path1" as the file.
        XCTAssertNil(sut.consume(
            line: "2026/08/12 11:37:28 INFO  : - Path2    Do queued copies to                - Path1"
        ))
        XCTAssertNil(sut.consume(
            line: "2026/08/12 11:37:28 INFO  : - Path1    Queue copy to Path2       - /vault/b/file1.md"
        ))
    }

    func testKeepsFilenamesContainingSpacedHyphen() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:28 INFO  : - Path1    File is new               - notes/my note - draft.md"
        )

        XCTAssertEqual(progress?.currentObject, "notes/my note - draft.md")
    }

    // MARK: - Stats block

    func testParsesByteStatsLine() {
        let progress = sut.consume(
            line: "Transferred:   \t    2.809 MiB / 38.147 MiB, 7%, 2.027 MiB/s, ETA 17s"
        )

        XCTAssertEqual(progress?.bytesTransferred, Int64(2.809 * 1_048_576))
        XCTAssertEqual(progress?.bytesTotal, Int64(38.147 * 1_048_576))
        XCTAssertEqual(progress?.speed, "2.027 MiB/s")
        XCTAssertEqual(progress?.eta, "17s")
    }

    func testParsesByteStatsInPlainBytes() {
        let progress = sut.consume(
            line: "Transferred:   \t         31 B / 31 B, 100%, 0 B/s, ETA -"
        )

        XCTAssertEqual(progress?.bytesTransferred, 31)
        XCTAssertEqual(progress?.bytesTotal, 31)
        XCTAssertNil(progress?.eta, "rclone writes an unknown ETA as \"-\"")
    }

    func testParsesFileCountStatsLine() {
        let progress = sut.consume(line: "Transferred:            2 / 3, 66%")

        XCTAssertEqual(progress?.filesDone, 2)
        XCTAssertEqual(progress?.filesTotal, 3)
    }

    func testByteAndCountLinesDoNotOverwriteEachOther() {
        _ = sut.consume(line: "Transferred:   \t    2.809 MiB / 38.147 MiB, 7%, 2.027 MiB/s, ETA 17s")
        let progress = sut.consume(line: "Transferred:            0 / 1, 0%")

        XCTAssertEqual(progress?.filesDone, 0)
        XCTAssertEqual(progress?.filesTotal, 1)
        XCTAssertEqual(progress?.bytesTotal, Int64(38.147 * 1_048_576))
    }

    func testParsesListedCount() {
        let progress = sut.consume(line: "Checks:                11 / 11, 100%, Listed 18")

        XCTAssertEqual(progress?.objectsListed, 18)
    }

    func testParsesInFlightTransferSpeedAndETA() {
        _ = sut.consume(line: "Transferring:")
        let progress = sut.consume(
            line: " *                                      blob.bin: 11% / 38.147 MiB, 2.014 MiB/s, 16s"
        )

        XCTAssertEqual(progress?.currentObject, "blob.bin")
        XCTAssertEqual(progress?.speed, "2.014 MiB/s")
        XCTAssertEqual(progress?.eta, "16s")
    }

    func testInFlightLineDoesNotOverwriteFullPathFromLog() {
        // rclone truncates long names in the Transferring block with an ellipsis,
        // so the full path from the log line must win.
        _ = sut.consume(line: "2026/08/12 12:43:05 INFO  : - Path1    File is new    - deep/nested/long-name.bin")
        _ = sut.consume(line: "Transferring:")
        let progress = sut.consume(
            line: " * a-very-long-directory-…runcated-somewhere.bin: 10% / 11.444 MiB, 0 B/s, -"
        )

        XCTAssertEqual(progress?.currentObject, "deep/nested/long-name.bin")
    }

    func testOnlyFirstInFlightObjectIsUsedPerBlock() {
        _ = sut.consume(line: "Transferring:")
        _ = sut.consume(line: " *                     first.bin: 10% / 1 MiB, 1 MiB/s, 1s")
        let progress = sut.consume(line: " *                    second.bin: 20% / 1 MiB, 2 MiB/s, 2s")

        XCTAssertNil(progress, "Only the representative first transfer is reported")
    }

    func testLaterInFlightObjectReplacesAnEarlierOne() {
        // Otherwise the popover keeps showing the first file for the whole sync.
        _ = sut.consume(line: "2026/08/12 11:37:28 INFO  : notes/first.md: Copied (new)")
        _ = sut.consume(line: "Transferring:")
        let progress = sut.consume(line: " *   notes/second.md: 20% / 1 MiB, 2 MiB/s, 2s")

        XCTAssertEqual(progress?.currentObject, "notes/second.md")
    }

    func testBlankLineEndsTransferringBlock() {
        _ = sut.consume(line: "Transferring:")
        _ = sut.consume(line: " *                     first.bin: 10% / 1 MiB, 1 MiB/s, 1s")
        _ = sut.consume(line: "")

        _ = sut.consume(line: "Transferring:")
        let progress = sut.consume(line: " *                    second.bin: 20% / 1 MiB, 2 MiB/s, 2s")

        XCTAssertEqual(progress?.currentObject, "second.bin")
    }

    // MARK: - Robustness

    func testStripsANSIColourCodes() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:15 INFO  : \u{1B}[32mBisync successful\u{1B}[0m"
        )

        XCTAssertEqual(progress?.phase, .finishing)
    }

    func testStripsANSIFromDiffScanLine() {
        let line = "2026/08/12 11:37:28 INFO  : - \u{1B}[36mPath1\u{1B}[0m    "
            + "\u{1B}[35m\u{1B}[32mFile is new\u{1B}[0m\u{1B}[0m               "
            + "- \u{1B}[36mbig/blob.bin\u{1B}[0m"

        XCTAssertEqual(sut.consume(line: line)?.currentObject, "big/blob.bin")
    }

    /// rclone puts the `INFO` prefix on its own line ahead of the stats block, so
    /// prefixed stats lines are not seen in practice. Parse them anyway rather
    /// than silently dropping throughput if a config emits them on one line.
    func testParsesStatsLineEvenWhenLogPrefixed() {
        let progress = sut.consume(
            line: "2026/08/12 11:37:28 INFO  : Transferred:   \t1.402 MiB / 38.147 MiB, 4%, 2.027 MiB/s, ETA 17s"
        )

        XCTAssertEqual(progress?.bytesTransferred, Int64(1.402 * 1_048_576))
        XCTAssertEqual(progress?.bytesTotal, Int64(38.147 * 1_048_576))
        XCTAssertEqual(progress?.speed, "2.027 MiB/s")
        XCTAssertEqual(progress?.eta, "17s")
    }

    /// The bare prefix line that precedes each stats block must not be mistaken
    /// for content or end a `Transferring:` block early.
    func testEmptyInfoLineBeforeStatsBlockIsIgnored() {
        XCTAssertNil(sut.consume(line: "2026/08/12 11:37:28 INFO  : "))
    }

    func testIgnoresUnrelatedLines() {
        XCTAssertNil(sut.consume(line: "2026/08/12 11:37:28 INFO  : Bisyncing with Comparison Settings: "))
        XCTAssertNil(sut.consume(line: "\t\"Modtime\": true,"))
        XCTAssertNil(sut.consume(line: ""))
    }

    // MARK: - Whole-run fixture

    // swiftlint:disable line_length

    /// A complete `bisync` run captured verbatim from rclone v1.75.0, including the
    /// bookkeeping lines that must never surface as the current object.
    private static let realDeltaRun = """
    2026/08/12 12:58:57 INFO  : Setting --ignore-listing-checksum as neither --checksum nor --compare checksum are set.
    2026/08/12 12:58:57 INFO  : Bisyncing with Comparison Settings:\u{20}
    {
    \t"Modtime": true,
    \t"Size": true,
    \t"HashType1": 0,
    }
    2026/08/12 12:58:57 INFO  : lock file renewed for 2m0s. New expiration: 2026-08-12 13:00:57.780907 -0400 EDT m=+120.015476543
    2026/08/12 12:58:57 INFO  : Synching Path1 "/vault/a/" with Path2 "/vault/b/"
    2026/08/12 12:58:57 INFO  : Building Path1 and Path2 listings
    2026/08/12 12:58:57 INFO  : Path1 checking for diffs
    2026/08/12 12:58:57 INFO  : - Path1             File changed: size (larger), time (newer)   - note1.md
    2026/08/12 12:58:57 INFO  : - Path1             File is new                                 - sub/blob2.bin
    2026/08/12 12:58:57 INFO  : Path1:    2 changes:    1 new,    1 modified,    0 deleted
    2026/08/12 12:58:57 INFO  : (Modified:    1 newer,    0 older,    1 larger,    0 smaller)
    2026/08/12 12:58:57 INFO  : Path2 checking for diffs
    2026/08/12 12:58:57 INFO  : - Path2             File is new                                 - onlyb.md
    2026/08/12 12:58:57 INFO  : Path2:    1 changes:    1 new,    0 modified,    0 deleted
    2026/08/12 12:58:57 INFO  : Applying changes
    2026/08/12 12:58:57 INFO  : - Path1             Queue copy to Path2                         - /vault/b/note1.md
    2026/08/12 12:58:57 INFO  : - Path2             Queue copy to Path1                         - /vault/a/onlyb.md
    2026/08/12 12:58:57 INFO  : - Path2             Do queued copies to                         - Path1
    2026/08/12 12:58:57 INFO  : onlyb.md: Copied (server-side copy)
    2026/08/12 12:58:57 INFO  : - Path1             Do queued copies to                         - Path2
    2026/08/12 12:58:57 INFO  : sub: Set directory modification time (using SetModTime)
    2026/08/12 12:58:57 INFO  : note1.md: Copied (server-side copy)
    2026/08/12 12:58:57 INFO  : sub/blob2.bin: Copied (server-side copy)
    2026/08/12 12:58:57 INFO  : Updating listings
    2026/08/12 12:58:57 INFO  : Validating listings for Path1 "/vault/a/" vs Path2 "/vault/b/"
    2026/08/12 12:58:57 INFO  : Bisync successful
    2026/08/12 12:58:57 INFO  :\u{20}
    Transferred:   \t    5.722 MiB / 5.722 MiB, 100%, 0 B/s, ETA -
    Checks:                85 / 85, 100%, Listed 52
    Transferred:            3 / 3, 100%
    Server Side Copies:     3 @ 5.722 MiB
    Elapsed time:         0.0s
    """

    // swiftlint:enable line_length

    func testRealRunEndsWithCompleteTotals() throws {
        var last: SyncProgress?
        for line in Self.realDeltaRun.components(separatedBy: "\n") {
            last = sut.consume(line: line) ?? last
        }

        let final = try XCTUnwrap(last)
        XCTAssertEqual(final.filesDone, 3)
        XCTAssertEqual(final.filesTotal, 3)
        XCTAssertEqual(final.bytesTransferred, final.bytesTotal)
        XCTAssertEqual(final.objectsListed, 52)
        XCTAssertEqual(final.fractionCompleted, 1)
    }

    func testRealRunNeverSurfacesBookkeepingAsTheCurrentObject() {
        var observed: Set<String> = []
        for line in Self.realDeltaRun.components(separatedBy: "\n") {
            if let object = sut.consume(line: line)?.currentObject {
                observed.insert(object)
            }
        }

        XCTAssertEqual(observed, ["note1.md", "sub/blob2.bin", "onlyb.md"])
    }

    func testRealRunVisitsPhasesInOrder() {
        var phases: [SyncPhase] = []
        for line in Self.realDeltaRun.components(separatedBy: "\n") {
            if let phase = sut.consume(line: line)?.phase, phases.last != phase {
                phases.append(phase)
            }
        }

        XCTAssertEqual(phases, [
            .starting,
            .buildingListings,
            .checkingDiffs(path: "Path1"),
            .checkingDiffs(path: "Path2"),
            .applyingChanges,
            .updatingListings,
            .validating,
            .finishing,
        ])
    }

    func testProgressAccumulatesAcrossLines() {
        _ = sut.consume(line: "2026/08/12 11:37:28 INFO  : Applying changes")
        _ = sut.consume(line: "2026/08/12 11:37:28 INFO  : file1.md: Copied (new)")
        _ = sut.consume(line: "Transferred:   \t    4.215 MiB / 38.147 MiB, 11%, 2.014 MiB/s, ETA 16s")
        let progress = sut.consume(line: "Transferred:            1 / 3, 33%")

        XCTAssertEqual(progress?.phase, .applyingChanges)
        XCTAssertEqual(progress?.currentObject, "file1.md")
        XCTAssertEqual(progress?.filesDone, 1)
        XCTAssertEqual(progress?.filesTotal, 3)
        XCTAssertEqual(progress?.speed, "2.014 MiB/s")
    }
}
