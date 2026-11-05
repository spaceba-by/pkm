@testable import PKMSync
import XCTest

final class UpdateSignatureVerifierTests: XCTestCase {
    /// Apple-signed and present on every macOS install, including CI runners.
    private let appleSignedApp = URL(fileURLWithPath: "/System/Applications/Calculator.app")

    func testAcceptsAppMatchingRequirement() throws {
        XCTAssertNoThrow(try UpdateSignatureVerifier.verify(appAt: appleSignedApp, requirement: "anchor apple"))
    }

    func testRejectsValidlySignedAppFromAnotherSigner() {
        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: appleSignedApp)) { error in
            guard case UpdateError.signatureInvalid = error else {
                return XCTFail("Expected signatureInvalid, got \(error)")
            }
        }
    }

    func testRejectsUnsignedApp() throws {
        let app = FileManager.default.temporaryDirectory
            .appendingPathComponent("Unsigned-\(UUID().uuidString).app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: app) }
        try Data("#!/bin/sh\n".utf8).write(to: macOS.appendingPathComponent("Unsigned"))

        XCTAssertThrowsError(try UpdateSignatureVerifier.verify(appAt: app)) { error in
            guard case UpdateError.signatureInvalid = error else {
                return XCTFail("Expected signatureInvalid, got \(error)")
            }
        }
    }
}
