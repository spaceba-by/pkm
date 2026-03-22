import Foundation
@testable import PKMSync

final class MockUpdateService: UpdateServiceProtocol, @unchecked Sendable {
    var checkResult: Result<AppUpdate?, Error> = .success(nil)
    var downloadResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/test.zip"))
    private(set) var checkCallCount = 0
    private(set) var downloadCallCount = 0
    private(set) var lastCheckedVersion: String?

    func checkForUpdate(currentVersion: String) async throws -> AppUpdate? {
        checkCallCount += 1
        lastCheckedVersion = currentVersion
        return try checkResult.get()
    }

    func downloadUpdate(_ update: AppUpdate, progress: @Sendable (Double) -> Void) async throws -> URL {
        downloadCallCount += 1
        progress(1.0)
        return try downloadResult.get()
    }
}
