import Foundation

// MARK: - FutureContinuationBox

/// Thread-safe continuation box used internally by ``Effect/future(_:scheduling:file:function:line:)``.
///
/// This type is an implementation detail of the `SwiftRexConcurrency` module. It has no public
/// surface and is not part of SwiftRex's public API.
///
/// ### Responsibility
///
/// `FutureContinuationBox` holds the `CheckedContinuation` that suspends the inner `Task` inside
/// `Effect.future`. It is shared between two competing contexts:
///
/// 1. **User completion** — the ``FutureCompleter/complete(_:)`` path, which arrives from
///    arbitrary thread (any completion-handler queue).
/// 2. **Task cancellation** — the `onCancel` handler of `withTaskCancellationHandler`, which
///    can fire from any thread as soon as the `Task` is cancelled.
///
/// The `NSLock` ensures exactly one of the two contexts wins: whichever calls `complete` or
/// `cancel` first resumes the continuation; the other call becomes a no-op (the stored
/// `continuation` is `nil` by then).
///
/// ### Why NSLock instead of an actor?
///
/// `CheckedContinuation.resume` must not be called from an async context because it could
/// re-enter the cooperative thread pool unexpectedly. `NSLock` is synchronous and unambiguous.
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
