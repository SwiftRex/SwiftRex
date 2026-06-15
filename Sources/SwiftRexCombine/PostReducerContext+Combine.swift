#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

// Combine's Future.Promise is (Result<Output, Failure>) -> Void — a plain function type that
// is not @Sendable. Wrapping it in this box lets us transfer it into a @MainActor Task without
// region-isolation diagnostics. The caller owns the box and the Task runs it exactly once.
private final class _PromiseBox<T>: @unchecked Sendable {
    let call: (Result<T, Never>) -> Void
    init(_ call: @escaping (Result<T, Never>) -> Void) { self.call = call }
}

extension PostReducerContext {
    /// Returns a single-element publisher that reads the Store's current state on the main actor.
    ///
    /// Uses `Deferred { Future }` so the state is read lazily — only when a subscriber
    /// attaches, not when the publisher is constructed. The emitted value reflects the Store's
    /// state at the moment of subscription; subscribing synchronously inside a `produce` closure
    /// yields this cycle's post-mutation state, while a later subscription yields whatever the
    /// Store holds then.
    ///
    /// ```swift
    /// Behavior<MyAction, MyState, API>.handle { action, _ in
    ///     guard case .save(let data) = action else { return .doNothing }
    ///     return .produce { ctx in
    ///         ctx.readLiveState()
    ///             .flatMap { state in ctx.environment.api.save(data, revision: state.revision) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `AnyPublisher<State, Never>` that emits the current state once and
    ///   completes. Emits nothing if the Store has been deallocated.
    public func readLiveState() -> AnyPublisher<State, Never> {
        Deferred {
            Future<State?, Never> { [self] promise in
                let box = _PromiseBox(promise)
                Task { @MainActor [self] in box.call(.success(self.liveState)) }
            }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
#endif
