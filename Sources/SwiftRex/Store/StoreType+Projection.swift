extension StoreType {
    /// Creates a ``StoreProjection`` that narrows this store to a local action and state interface.
    ///
    /// The projection holds no state of its own — `state` is recomputed from the underlying
    /// store on every access by applying `mapState`. Actions dispatched to the projection are
    /// transformed by `mapAction` before reaching the underlying store.
    ///
    /// Global types appear only in this call; the resulting ``StoreProjection`` exposes only
    /// `LocalAction` and `LocalState`:
    ///
    /// ```swift
    /// let counterStore = appStore.projection(
    ///     action: { AppAction.counter($0) },  // CounterAction → AppAction
    ///     state:  { $0.counterState }          // AppState → CounterState
    /// )
    /// // counterStore: StoreProjection<CounterAction, CounterState>
    /// ```
    ///
    /// Delegates to ``StoreProjection/init(store:action:state:)``.
    ///
    /// - Parameters:
    ///   - mapAction: Converts a local `LocalAction` into this store's `Action` type.
    ///   - mapState: Projects this store's `State` type to the local `LocalState`.
    /// - Returns: A ``StoreProjection`` presenting the narrower `(LocalAction, LocalState)` interface.
    public func projection<LocalAction: Sendable, LocalState: Sendable>(
        action mapAction: @escaping @Sendable (LocalAction) -> Action,
        state mapState: @escaping @MainActor @Sendable (State) -> LocalState
    ) -> StoreProjection<LocalAction, LocalState> {
        StoreProjection(store: self, action: mapAction, state: mapState)
    }
}
