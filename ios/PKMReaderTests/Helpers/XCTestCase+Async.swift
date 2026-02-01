import XCTest

extension XCTestCase {
    /// Wait for an async operation to complete with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default 5 seconds)
    ///   - operation: The async operation to perform
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async operation")

        Task {
            do {
                try await operation()
            } catch {
                XCTFail("Async operation failed: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Wait for a condition to become true with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default 5 seconds)
    ///   - pollInterval: How often to check the condition (default 0.1 seconds)
    ///   - condition: The condition to check
    func waitFor(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) {
        let start = Date()

        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Condition not met within timeout")
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
    }
}
