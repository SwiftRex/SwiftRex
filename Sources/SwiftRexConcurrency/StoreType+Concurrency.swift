import CoreFP
import SwiftRex

// MARK: - Store observation as DeferredStream

extension StoreType where State: Sendable {
    /// A lazy `DeferredStream<State>` that emits the current state after every mutation.
    ///
    /// The store is observed only when `for await` iteration begins — each new iterator creates
    /// an independent ``SubscriptionToken`` via ``StoreType/observe(willChange:didChange:)``.
    /// Ending the `for await` loop (by `break`, `return`, or task cancellation) cancels the
    /// token and removes the observer from the store.
    ///
    /// Because the underlying `AsyncStream` is bound to `@MainActor`, the yielded state
    /// reflects the store's value immediately after each `@MainActor` mutation. Use
    /// `.map(\.someSubstate)` to project only the fields you care about.
    ///
    /// ```swift
    /// // Iterate state changes on the main actor
    /// for await state in store.stream {
    ///     updateUI(state)
    /// }
    ///
    /// // Project and deduplicate
    /// for await username in store.stream.map(\.username) {
    ///     nameLabel.text = username
    /// }
    ///
    /// // Bridge to an Effect for middleware use
    /// Effect<AppAction>.deferredStream(store.stream, AppAction.stateChanged)
    /// ```
    ///
    /// - Note: `DeferredStream` is defined in the `CoreFP` library. It is a lazy
    ///   `AsyncSequence` that creates a fresh `AsyncStream` for each iteration.
    public var stream: DeferredStream<State> {
        DeferredStream { [self] in
            AsyncStream { continuation in
                Task { @MainActor [self] in
                    let token = self.observe(didChange: { @MainActor [self] in
                        continuation.yield(self.state)
                    })
                    continuation.onTermination = { _ in token.cancel() }
                }
            }
        }
    }
}
