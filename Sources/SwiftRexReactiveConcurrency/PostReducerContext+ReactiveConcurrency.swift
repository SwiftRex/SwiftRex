// SPDX-License-Identifier: Apache-2.0

#if ReactiveConcurrency
    import ReactiveConcurrency
    import SwiftRex

    extension PostReducerContext {
        /// Returns a single-element publisher that reads the Store's current state on the main actor.
        ///
        /// The state is read lazily — only when a subscriber attaches, not when the publisher is
        /// constructed. The emitted value reflects the Store's state at the moment of subscription;
        /// subscribing synchronously inside a `produce` closure yields this cycle's post-mutation
        /// state, while a later subscription yields whatever the Store holds then.
        ///
        /// ```swift
        /// Behavior<MyAction, MyState, API>.handle { action, _ in
        ///     guard case .save(let data) = action else { return .doNothing }
        ///     return .react { ctx in
        ///         ctx.readLiveState()
        ///             .flatMap { state in ctx.environment.api.save(data, revision: state.revision) }
        ///             .asEffect()
        ///     }
        /// }
        /// ```
        ///
        /// - Returns: A `Publisher<State, Never>` that emits the current state once and completes.
        ///   Emits nothing if the Store has been deallocated.
        public func readLiveState() -> Publisher<State, Never> {
            Publisher { continuation in
                if let state = await MainActor.run(body: { self.liveState }) {
                    continuation.yield(state)
                }
                continuation.finish()
            }
        }
    }
#endif
