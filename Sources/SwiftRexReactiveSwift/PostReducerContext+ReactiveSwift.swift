// SPDX-License-Identifier: Apache-2.0

#if ReactiveSwift
    @preconcurrency import ReactiveSwift
    import SwiftRex

    extension PostReducerContext {
        /// Returns a single-element `SignalProducer` that reads the Store's current state on the
        /// main actor.
        ///
        /// `SignalProducer` is cold — the state read is deferred until a subscriber starts the
        /// producer. The emitted value reflects the Store's state at the moment of subscription;
        /// starting it synchronously inside a `produce` closure yields this cycle's post-mutation
        /// state, while a later start yields whatever the Store holds then.
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
        /// - Returns: A `SignalProducer<State, Never>` that emits the current state once and
        ///   completes. Emits nothing (only completes) if the Store has been deallocated.
        public func readLiveState() -> SignalProducer<State, Never> {
            SignalProducer { [self] observer, _ in
                Task { @MainActor [self] in
                    if let state = liveState {
                        observer.send(value: state)
                    }
                    observer.sendCompleted()
                }
            }
        }
    }
#endif
