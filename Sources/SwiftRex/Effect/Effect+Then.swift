import Foundation

// MARK: - Sequential composition

extension Effect {
    /// Runs `self` to completion, then runs `next`. All actions from both effects are dispatched.
    ///
    /// **Cascade cancellation.** Cancelling the chain's `SubscriptionToken` cancels the
    /// currently-running phase and prevents any remaining phases from starting. This works
    /// naturally because cancelled effects must not call `complete` — so if `self` is cancelled,
    /// `next` is never started.
    ///
    /// **Scheduling.** Each component retains its original `EffectScheduling`. The `then` result
    /// is a single logical unit; apply `.scheduling(...)` to the whole chain if needed.
    ///
    /// ```swift
    /// startBluetoothRadio.then(startDiscovery)
    /// // One Effect — no intermediate action required.
    /// ```
    public func then(_ next: Effect<Action>) -> Effect<Action> {
        guard !components.isEmpty else { return next }
        guard !next.components.isEmpty else { return self }

        return Effect(components: [
            Component(subscribe: { send, outerComplete in
                let nextRef = TokenRef()
                let selfToken = self.subscribeSequentially(send: send) {
                    nextRef.value = next.subscribeSequentially(send: send, complete: outerComplete)
                }
                return SubscriptionToken { selfToken.cancel(); nextRef.value.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Internal helpers

extension Effect {
    /// Subscribes all components, calling `complete` only when every component has completed.
    /// Used by `then` to treat a multi-component effect as a single sequential unit.
    func subscribeSequentially(
        send: @escaping @Sendable (DispatchedAction<Action>) -> Void,
        complete: @escaping @Sendable () -> Void
    ) -> SubscriptionToken {
        guard !components.isEmpty else { complete(); return .empty }

        let counter = CompletionCounter(target: components.count, onComplete: complete)
        let tokens = components.map { component in
            component.subscribe(send) { counter.signal() }
        }
        return SubscriptionToken { tokens.forEach { $0.cancel() } }
    }
}

// MARK: - Shared helpers

/// Fires `onComplete` after `target` calls to `signal()`.
final class CompletionCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: Int
    private let onComplete: @Sendable () -> Void

    init(target: Int, onComplete: @escaping @Sendable () -> Void) {
        self.remaining = target
        self.onComplete = onComplete
    }

    func signal() {
        let done = lock.withLock { remaining -= 1; return remaining <= 0 }
        if done { onComplete() }
    }
}

/// Reference wrapper for a `SubscriptionToken`, safe to capture in `@Sendable` closures.
final class TokenRef: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: SubscriptionToken = .empty
    var value: SubscriptionToken {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
