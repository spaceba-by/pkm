import Foundation

/// Bridges `Process.terminationHandler` to `async`/`await`.
///
/// Exists because `Process.waitUntilExit()` spins a `CFRunLoop` on whichever
/// thread calls it. On a libdispatch worker thread nothing services that run
/// loop's termination source, so the call can block forever — reproduced by
/// looping a trivial child process, which hung within ~10-25 iterations.
///
/// Install the handler *before* `Process.run()`: a child that exits before
/// `wait()` is reached still records the exit, and `wait()` returns immediately.
final class ProcessExitWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var hasExited = false
    private var continuation: CheckedContinuation<Void, Never>?

    /// Called from `Process.terminationHandler`, on an arbitrary thread.
    func signal() {
        lock.lock()
        hasExited = true
        let pending = continuation
        continuation = nil
        lock.unlock()
        // Resumed outside the lock: the continuation may run arbitrary code.
        pending?.resume()
    }

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if hasExited {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }
}
