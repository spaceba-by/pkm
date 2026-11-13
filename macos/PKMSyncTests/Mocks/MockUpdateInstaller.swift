import Foundation
@testable import PKMSync

final class MockUpdateInstaller: @unchecked Sendable {
    var installResult: Result<Void, Error> = .success(())
    var installGate: AsyncGate?
    private(set) var installCallCount = 0

    func install(_: URL) async throws {
        installCallCount += 1
        if let installGate {
            await installGate.wait()
        }
        try installResult.get()
    }
}
