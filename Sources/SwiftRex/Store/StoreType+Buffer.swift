extension StoreType {
    /// Wraps this store in a `StoreBuffer` that caches state and only fires observers
    /// when `hasChanged` returns `true`. Delegates to `StoreBuffer.init(_:hasChanged:)`.
    ///
    /// ```swift
    /// store.projection(action:state:).buffer { $0.count != $1.count }
    /// ```
    public func buffer(
        hasChanged: @escaping @Sendable (State, State) -> Bool
    ) -> StoreBuffer<Action, State> {
        StoreBuffer(self, hasChanged: hasChanged)
    }

    /// Wraps this store in a `StoreBuffer` using `!=` as the predicate.
    /// Delegates to the `Equatable` convenience init on `StoreBuffer`.
    public func buffer() -> StoreBuffer<Action, State> where State: Equatable {
        StoreBuffer(self)
    }
}
