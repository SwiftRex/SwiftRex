// MARK: - Functor

extension Effect {
    /// Transforms the action type produced by this effect, preserving all other structure.
    ///
    /// `Effect` is a **Functor**: `map` applies `f` to every raw action value emitted by
    /// every component, while keeping the original ``ActionSource`` dispatcher intact. The
    /// `complete` callback and the ``EffectScheduling`` policy on each component pass through
    /// unchanged.
    ///
    /// This is the primary mechanism for lifting a feature-level effect into the global action
    /// space:
    ///
    /// ```swift
    /// // authEffect: Effect<AuthAction>
    /// // mapped:     Effect<AppAction>
    /// let mapped = authEffect.map { AppAction.auth($0) }
    /// ```
    ///
    /// Internally used by ``Middleware/liftAction(_:)`` and ``Behavior/liftAction(_:)`` to
    /// re-wrap outgoing actions through a `Prism.review` function.
    ///
    /// - Parameter f: A `@Sendable` function from `Action` to `B`. Applied to every emitted
    ///   raw action value. The ``ActionSource`` dispatcher is passed through unmodified.
    /// - Returns: An `Effect<B>` whose components correspond 1:1 to this effect's components,
    ///   each mapping emitted actions through `f`.
    public func map<B: Sendable>(_ f: @Sendable @escaping (Action) -> B) -> Effect<B> {
        Effect<B>(components: components.map { component in
            Effect<B>.Component(
                subscribe: { send, complete in
                    component.subscribe({ send($0.map(f)) }, complete)
                },
                scheduling: component.scheduling
            )
        })
    }
}
