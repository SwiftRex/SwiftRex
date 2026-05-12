// MARK: - Functor

extension Effect {
    /// Transforms the action type. The `ActionSource` dispatcher is preserved — only the
    /// raw action value is passed through `f`.
    ///
    /// ```swift
    /// let effect: Effect<LocalAction> = ...
    /// let lifted: Effect<GlobalAction> = effect.map(GlobalAction.local)
    /// ```
    public func map<B: Sendable>(_ f: @Sendable @escaping (Action) -> B) -> Effect<B> {
        Effect<B>(components: components.map { component in
            Effect<B>.Component(
                subscribe: { send in component.subscribe { send($0.map(f)) } },
                scheduling: component.scheduling
            )
        })
    }
}
