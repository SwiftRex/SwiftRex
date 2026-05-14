extension StoreType {
    /// Projects this store to a narrower action and state interface.
    ///
    /// The projection holds no state of its own — `state` is re-computed on every access.
    /// Delegates to `StoreProjection.init(store:action:state:)`.
    ///
    /// ```swift
    /// appStore.projection(action: AppAction.counter, state: \.counterState)
    /// ```
    public func projection<LocalAction: Sendable, LocalState: Sendable>(
        action mapAction: @escaping @Sendable (LocalAction) -> Action,
        state mapState: @escaping @MainActor @Sendable (State) -> LocalState
    ) -> StoreProjection<LocalAction, LocalState> {
        StoreProjection(store: self, action: mapAction, state: mapState)
    }
}
