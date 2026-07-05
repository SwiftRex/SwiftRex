import CoreFP

extension StoreType where Action: Prismatic {
    /// Projects this store to a child feature using a **prism key path** for the action and a
    /// read key path for the state — the ergonomic form for a router that resolves a route to a
    /// child view.
    ///
    /// The prism's `review` embeds the child action back into this store's action; the key path
    /// reads the child's state slice. Equivalent to the closure-based
    /// ``projection(action:state:)`` with `action: prism.review` and `state: { $0[keyPath:] }`.
    ///
    /// ```swift
    /// // in a router's @ViewBuilder switch:
    /// Detail.view(
    ///     store: store.projection(action: \.detail, state: \.detail),
    ///     environment: world.detailEnvironment
    /// )
    /// ```
    @MainActor
    public func projection<LocalAction: Sendable, LocalState: Sendable>(
        action prism: PrismKeyPath<Action, LocalAction>,
        state keyPath: KeyPath<State, LocalState>
    ) -> StoreProjection<LocalAction, LocalState> {
        let review = Prism(prism).review
        return projection(action: review, state: { $0[keyPath: keyPath] })
    }
}
