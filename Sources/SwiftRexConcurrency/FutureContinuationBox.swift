import Foundation

// Thread-safe box shared between the async body and withTaskCancellationHandler.onCancel.
// The lock ensures exactly one of (user completing, cancellation) wins — the other is a no-op.
final class FutureContinuationBox<A: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<A?, Never>?

    func store(_ c: CheckedContinuation<A?, Never>) {
        lock.withLock { continuation = c }
    }

    func complete(_ value: A) {
        lock.withLock { continuation?.resume(returning: value); continuation = nil }
    }

    func cancel() {
        lock.withLock { continuation?.resume(returning: nil); continuation = nil }
    }
}
