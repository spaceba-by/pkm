@testable import PKMSync
import XCTest

final class SyncConfigurationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: SyncConfiguration!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SyncConfigurationTests")!
        defaults.removePersistentDomain(forName: "SyncConfigurationTests")
        sut = SyncConfiguration(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SyncConfigurationTests")
        super.tearDown()
    }

    func testDefaultValues() {
        XCTAssertEqual(sut.vaultPath, "")
        XCTAssertEqual(sut.bucketName, "")
        XCTAssertEqual(sut.syncIntervalMinutes, 5)
        XCTAssertEqual(sut.launchAtLogin, false)
        XCTAssertEqual(sut.rclonePath, "")
        XCTAssertEqual(sut.filterFilePath, "")
        XCTAssertEqual(sut.maxLogEntries, 50)
    }

    func testAgentPullEnabledDefaultsToTrue() {
        XCTAssertTrue(sut.agentPullEnabled)

        sut.agentPullEnabled = false
        XCTAssertFalse(SyncConfiguration(defaults: defaults).agentPullEnabled)
    }

    func testResolvedFilterFilePathFallsBackToManagedDefault() {
        XCTAssertEqual(sut.resolvedFilterFilePath(), BisyncFilterFile.defaultPath())

        sut.filterFilePath = "/Users/test/custom-filter.txt"
        XCTAssertEqual(sut.resolvedFilterFilePath(), "/Users/test/custom-filter.txt")
    }

    /// The _agent/ exclusion is what keeps agent output out of the bidirectional
    /// phase; without it the one-way pull would fight bisync.
    func testDefaultFilterContentsExcludeAgentPrefix() {
        XCTAssertTrue(BisyncFilterFile.defaultContents.contains("- /_agent/**"))
        XCTAssertTrue(BisyncFilterFile.defaultContents.contains("- /_agent/"))
        XCTAssertTrue(BisyncFilterFile.excludesAgent(BisyncFilterFile.defaultContents))
    }

    func testExcludesAgentRequiresRuleBeforeAnyInclude() {
        // rclone applies the first matching rule, so `+ **` first wins.
        XCTAssertFalse(BisyncFilterFile.excludesAgent("+ **\n- /_agent/**\n"))
        XCTAssertFalse(BisyncFilterFile.excludesAgent("- .DS_Store\n+ **\n"))
        XCTAssertFalse(BisyncFilterFile.excludesAgent("# - /_agent/**\n"))
        XCTAssertTrue(BisyncFilterFile.excludesAgent("- .DS_Store\n  - /_agent/**\n+ **\n"))
    }

    /// A `!` line makes rclone clear every rule above it, so an exclusion
    /// before a reset protects nothing.
    func testExcludesAgentIgnoresRulesBeforeLastReset() {
        XCTAssertFalse(BisyncFilterFile.excludesAgent("- /_agent/**\n!\n+ **\n"))
        XCTAssertFalse(BisyncFilterFile.excludesAgent("- /_agent/**\n  !  \n"))
        XCTAssertFalse(BisyncFilterFile.excludesAgent("!\n- /_agent/**\n!\n- .DS_Store\n"))
        XCTAssertTrue(BisyncFilterFile.excludesAgent("+ **\n!\n- /_agent/**\n+ **\n"))
        XCTAssertTrue(BisyncFilterFile.excludesAgent("# !\n- /_agent/**\n+ **\n"))
    }

    func testInsertingAgentExclusionGoesAfterLastReset() {
        let custom = "- .DS_Store\n!\n+ /notes/**\n!\n+ **\n"
        let result = BisyncFilterFile.insertingAgentExclusion(into: custom)

        XCTAssertEqual(
            result,
            "- .DS_Store\n!\n+ /notes/**\n!\n" + BisyncFilterFile.agentExclusionBlock + "+ **\n"
        )
        XCTAssertTrue(BisyncFilterFile.excludesAgent(result))
    }

    func testInsertingAgentExclusionHandlesResetOnLastLine() {
        let result = BisyncFilterFile.insertingAgentExclusion(into: "+ **\n!")

        XCTAssertEqual(result, "+ **\n!\n" + String(BisyncFilterFile.agentExclusionBlock.dropLast()))
        XCTAssertTrue(BisyncFilterFile.excludesAgent(result))
    }

    func testInsertingAgentExclusionPrependsWithoutReset() {
        let custom = "- .DS_Store\n+ **\n"
        XCTAssertEqual(
            BisyncFilterFile.insertingAgentExclusion(into: custom),
            BisyncFilterFile.agentExclusionBlock + custom
        )
    }

    func testPersistsValues() {
        sut.vaultPath = "/Users/test/vault"
        sut.bucketName = "my-bucket"
        sut.syncIntervalMinutes = 10

        let freshConfig = SyncConfiguration(defaults: defaults)
        XCTAssertEqual(freshConfig.vaultPath, "/Users/test/vault")
        XCTAssertEqual(freshConfig.bucketName, "my-bucket")
        XCTAssertEqual(freshConfig.syncIntervalMinutes, 10)
    }

    func testIsConfigured() {
        XCTAssertFalse(sut.isConfigured)

        sut.vaultPath = "/some/path"
        XCTAssertFalse(sut.isConfigured)

        sut.bucketName = "bucket"
        XCTAssertTrue(sut.isConfigured)
    }

    func testUpdateDefaults() {
        XCTAssertTrue(sut.autoCheckForUpdates)
        XCTAssertEqual(sut.updateCheckIntervalHours, 4)
    }

    func testPersistsUpdateValues() {
        sut.autoCheckForUpdates = false
        sut.updateCheckIntervalHours = 12

        let freshConfig = SyncConfiguration(defaults: defaults)
        XCTAssertFalse(freshConfig.autoCheckForUpdates)
        XCTAssertEqual(freshConfig.updateCheckIntervalHours, 12)
    }

    func testSyncIntervalSeconds() {
        sut.syncIntervalMinutes = 5
        XCTAssertEqual(sut.syncIntervalSeconds, 300)

        sut.syncIntervalMinutes = 1
        XCTAssertEqual(sut.syncIntervalSeconds, 60)
    }
}
