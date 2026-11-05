@testable import PKMSync
import XCTest

final class UpdateInstallerTests: XCTestCase {
    private var directory: URL!
    private var current: URL!
    private var new: URL!
    private var backup: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateInstallerTests-\(UUID().uuidString)")
        current = directory.appendingPathComponent("PKMSync.app")
        new = directory.appendingPathComponent("New.app")
        backup = directory.appendingPathComponent("PKMSync.backup.app")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: current.appendingPathComponent("marker"))
        try Data("new".utf8).write(to: new.appendingPathComponent("marker"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func marker(in app: URL) throws -> String {
        try String(contentsOf: app.appendingPathComponent("marker"), encoding: .utf8)
    }

    func testReplaceAppInstallsNewVersionAndKeepsBackup() throws {
        try UpdateInstaller.replaceApp(at: current, with: new, backupURL: backup)

        XCTAssertEqual(try marker(in: current), "new")
        XCTAssertEqual(try marker(in: backup), "old")
    }

    func testReplaceAppRestoresBackupWhenInstallFails() throws {
        XCTAssertThrowsError(
            try UpdateInstaller.replaceApp(at: current, with: new, backupURL: backup) { source, destination in
                if source == self.new { throw CocoaError(.fileWriteUnknown) }
                try FileManager.default.moveItem(at: source, to: destination)
            }
        ) { error in
            guard case UpdateError.installFailed = error else {
                return XCTFail("Expected installFailed, got \(error)")
            }
        }

        XCTAssertEqual(try marker(in: current), "old")
    }

    func testReplaceAppReportsBackupLocationWhenRollbackFails() throws {
        XCTAssertThrowsError(
            try UpdateInstaller.replaceApp(at: current, with: new, backupURL: backup) { source, destination in
                if source == self.new || source == self.backup { throw CocoaError(.fileWriteUnknown) }
                try FileManager.default.moveItem(at: source, to: destination)
            }
        ) { error in
            guard case let UpdateError.rollbackFailed(_, _, backupPath) = error else {
                return XCTFail("Expected rollbackFailed, got \(error)")
            }
            XCTAssertEqual(backupPath, self.backup.path)
            XCTAssertTrue(error.localizedDescription.contains(self.backup.path))
        }

        XCTAssertEqual(try marker(in: backup), "old")
    }
}
