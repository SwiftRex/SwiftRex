#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

extension StateAccess {
    /// Returns a single-element publisher that reads the current state on the main actor.
    ///
    /// Uses `Deferred { Future }` so the state is read lazily — only when a subscriber
    /// attaches, not when the publisher is constructed. This preserves the three-phase
    /// timing contract: the state you receive reflects the Store's state at the moment of
    /// subscription, which inside a `Reader` closure is post-mutation state.
    ///
    /// ```swift
    /// Middleware<MyAction, MyState, MyEnvironment>.handle { _, stateAccess in
    ///     Reader { env in
    ///         stateAccess.readState()
    ///             .flatMap { currentState in env.api.fetch(currentState.query) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `AnyPublisher<State, Never>` that emits the current state once and
    ///   completes. Emits nothing if the Store has been deallocated.
    public func readState() -> AnyPublisher<State, Never> {
        Deferred {
            Future<State?, Never> { promise in
                Task { @MainActor [self] in promise(.success(self.state)) }
            }
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
#endif
