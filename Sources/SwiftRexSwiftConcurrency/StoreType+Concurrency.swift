// SPDX-License-Identifier: Apache-2.0

import SwiftRex

// MARK: - Store observation as a lazy AsyncStream factory

extension StoreType where State: Sendable {
    /// A lazy `() -> AsyncStream<State>` that emits the current state after every mutation.
    ///
    /// It is a **factory**, not a stream: calling it starts a fresh, independent observation.
    /// Each call creates its own ``SubscriptionToken`` via ``StoreType/observe(willChange:didChange:)``;
    /// ending the `for await` loop (by `break`, `return`, or task cancellation) cancels the token
    /// and removes the observer from the store.
    ///
    /// Because the underlying `AsyncStream` is bound to `@MainActor`, the yielded state reflects
    /// the store's value immediately after each `@MainActor` mutation. Project with the standard
    /// `AsyncSequence.map`:
    ///
    /// ```swift
    /// // Iterate state changes on the main actor
    /// for await state in store.stream() {
    ///     updateUI(state)
    /// }
    ///
    /// // Project a sub-state
    /// for await username in store.stream().map(\.username) {
    ///     nameLabel.text = username
    /// }
    /// ```
    ///
    /// - Returns: A `@Sendable` closure producing a fresh `AsyncStream<State>` per call. The bare
    ///   closure is intentional: giving it `map`/`flatMap` would amount to re-growing a deferred
    ///   stream type, which now lives in the reactive-concurrency framework — use the
    ///   `AsyncSequence` operators on the produced stream instead.
    public var stream: @Sendable () -> AsyncStream<State> {
        { @Sendable in
            AsyncStream { continuation in
                Task { @MainActor in
                    let token = self.observe(didChange: { @MainActor in
                        continuation.yield(self.state)
                    })
                    continuation.onTermination = { _ in token.cancel() }
                }
            }
        }
    }
}
