extension StoreType {
    /// Wraps this store in a ``StoreBuffer`` that caches state and only notifies observers
    /// when `hasChanged(oldState, newState)` returns `true`.
    ///
    /// Use this to add notification deduplication after a ``StoreProjection`` has narrowed
    /// the types:
    ///
    /// ```swift
    /// // Step 1 — narrow types
    /// let proj = appStore.projection(
    ///     action: { AppAction.counter($0) },
    ///     state:  { $0.counterState }
    /// )
    ///
    /// // Step 2 — add deduplication with a custom predicate
    /// let buffered = proj.buffer { old, new in old.count != new.count }
    /// ```
    ///
    /// Delegates to ``StoreBuffer/init(_:hasChanged:)``.
    ///
    /// - Parameter hasChanged: A predicate called with `(oldState, newState)`. Return `true`
    ///   to propagate notifications and update the cached state; return `false` to suppress them.
    /// - Returns: A ``StoreBuffer`` observing this store and gating notifications through `hasChanged`.
    public func buffer(
        hasChanged: @escaping @Sendable (State, State) -> Bool
    ) -> StoreBuffer<Action, State> {
        StoreBuffer(self, hasChanged: hasChanged)
    }

    /// Wraps this store in a ``StoreBuffer`` using `!=` as the change predicate.
    ///
    /// Available when `State: Equatable`. Notifies observers only when the new state differs
    /// from the cached state under `Equatable` equality:
    ///
    /// ```swift
    /// // CounterState: Equatable — no predicate needed
    /// let buffered = counterProj.buffer()
    /// ```
    ///
    /// Delegates to ``StoreBuffer/init(_:)`` (the `Equatable` convenience initialiser).
    ///
    /// - Returns: A ``StoreBuffer`` that uses `!=` to gate notifications.
    public func buffer() -> StoreBuffer<Action, State> where State: Equatable {
        StoreBuffer(self)
    }
}
