// SPDX-License-Identifier: Apache-2.0

#if ReactiveConcurrency
    import ReactiveConcurrency
    import SwiftRex

    // MARK: - Store observation as Publisher

    extension StoreType {
        /// A cold `Publisher<State, Never>` that emits the current state after every mutation.
        ///
        /// Subscribes lazily — ``StoreType/observe(willChange:didChange:)`` is only called when a
        /// subscriber attaches (the publisher is backed by `ReactiveConcurrency`'s cold
        /// `DeferredStream`). Each subscription registers its own observer on the `@MainActor` and
        /// receives an independent `AnyCancellable`; cancelling it removes the observer from the
        /// store immediately.
        ///
        /// Each emission reads ``StoreType/state`` once on the `@MainActor` right after the mutation.
        /// Use `ReactiveConcurrency` operators (`map`, `removeDuplicates`, `receive(on:)`, …) to shape
        /// the stream:
        ///
        /// ```swift
        /// store.publisher
        ///     .map(\.username)
        ///     .removeDuplicates()
        ///     .sink { name in print(name) }
        ///     .store(in: &cancellables)
        /// ```
        ///
        /// To create an ``Effect`` from this publisher, use one of the
        /// ``ReactiveConcurrency/Publisher/asEffect`` overloads provided by `SwiftRexReactiveConcurrency`.
        public var publisher: Publisher<State, Never> {
            Publisher { continuation in
                // The Publisher body runs off the main actor; hop on to register the observer and
                // capture the token, then park until the subscription is cancelled and tear down.
                let token = await MainActor.run {
                    self.observe(didChange: { continuation.yield(self.state) })
                }
                await continuation.suspendUntilCancelled()
                token.cancel()
            }
        }
    }
#endif
