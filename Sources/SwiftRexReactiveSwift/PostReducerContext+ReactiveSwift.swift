@preconcurrency import ReactiveSwift
import SwiftRex

extension PostReducerContext {
    /// Returns a single-element `SignalProducer` that reads the post-mutation state on the
    /// main actor.
    ///
    /// `SignalProducer` is cold — the state read is deferred until a subscriber starts the
    /// producer. This ensures the state read always reflects the Store's state at the moment
    /// of subscription, which inside a `produce` closure is post-mutation state.
    ///
    /// ```swift
    /// Behavior<MyAction, MyState, API>.handle { action, _ in
    ///     guard case .save(let data) = action else { return .doNothing }
    ///     return .produce { ctx in
    ///         ctx.readStateAfter()
    ///             .flatMap { state in ctx.environment.api.save(data, revision: state.revision) }
    ///             .asEffect()
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: A `SignalProducer<State, Never>` that emits the post-mutation state once and
    ///   completes. Emits nothing (only completes) if the Store has been deallocated.
    public func readStateAfter() -> SignalProducer<State, Never> {
        SignalProducer { [self] observer, _ in
            Task { @MainActor [self] in
                if let state = self.stateAfter {
                    observer.send(value: state)
                }
                observer.sendCompleted()
            }
        }
    }
}
