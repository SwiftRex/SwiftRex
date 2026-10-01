// SPDX-License-Identifier: Apache-2.0

extension StoreType {
    /// Wraps this store in a ``StoreBuffer`` that passes a state on only when
    /// `hasChanged(previousState, newState)` returns `true`. Each observer remembers its own previous
    /// value; nothing is cached in the stage.
    ///
    /// ```swift
    /// // Step 1 — narrow types
    /// let proj = appStore.projection(.action(\.counter).state(\.counter))
    ///
    /// // Step 2 — skip repeats with a custom predicate
    /// let buffered = proj.buffer { old, new in old.count != new.count }
    /// ```
    ///
    /// Delegates to ``StoreBuffer/init(_:hasChanged:)``.
    ///
    /// - Parameter hasChanged: A predicate called with `(previousState, newState)`. Return `true`
    ///   to pass the new state on; return `false` to skip it.
    /// - Returns: A ``StoreBuffer`` following this store and skipping states `hasChanged` rejects.
    public func buffer(
        hasChanged: @escaping @Sendable (State, State) -> Bool
    ) -> StoreBuffer<Action, State> {
        StoreBuffer(self, hasChanged: hasChanged)
    }

    /// Wraps this store in a ``StoreBuffer`` using `!=` as the change predicate.
    ///
    /// Available when `State: Equatable`. Passes a state on only when it differs from the
    /// previous one (per observer) under `Equatable` equality:
    ///
    /// ```swift
    /// // CounterState: Equatable — no predicate needed
    /// let buffered = counterProj.buffer()
    /// ```
    ///
    /// Delegates to ``StoreBuffer/init(_:)`` (the `Equatable` convenience initialiser).
    ///
    /// - Returns: A ``StoreBuffer`` that uses `!=` to skip repeats.
    public func buffer() -> StoreBuffer<Action, State> where State: Equatable {
        StoreBuffer(self)
    }
}
