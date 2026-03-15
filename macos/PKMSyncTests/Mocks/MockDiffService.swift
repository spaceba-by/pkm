import Foundation
@testable import PKMSync

final class MockDiffService: DiffServiceProtocol, @unchecked Sendable {
    var result: [DiffLine] = []
    var error: Error?
    private(set) var diffCallCount = 0

    func diff(originalPath _: String, conflictPath _: String) async throws -> [DiffLine] {
        diffCallCount += 1
        if let error {
            throw error
        }
        return result
    }
}
