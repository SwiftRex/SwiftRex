import CoreFP
import DataStructure

// MARK: - SwiftRex bridge: .doNothing for Effect pipelines
//
// `Reader: Semigroup/Monoid where Output: Semigroup/Monoid` is provided natively
// by FP 1.6.6+ (luizmb/FP#40). `.doNothing` is SwiftRex vocabulary layered on top —
// it reads naturally at Middleware and Behavior call sites where the return type is
// `Reader<Environment, Effect<Action>>`:
//
//   guard case .fetchData(let q) = action.action else { return .doNothing }

extension Reader where Output: Monoid {
    /// Produces no effect for any environment.
    ///
    /// The idiomatic SwiftRex way to early-exit a ``Middleware/handle`` or
    /// ``Behavior/handle`` closure when an action is not relevant:
    ///
    /// ```swift
    /// guard case .fetchData(let query) = action.action else { return .doNothing }
    /// ```
    ///
    /// Equivalent to `Reader { _ in .empty }` but communicates intent clearly.
    public static var doNothing: Self { .identity }
}

// MARK: - .produce for Effect pipelines

extension Reader {
    /// Creates a `Reader<Environment, Effect<Action>>` from a closure that receives
    /// the environment and returns an `Effect`.
    ///
    /// Mirrors ``Consequence/produce(_:)`` so `Middleware` and `Behavior` handlers
    /// share the same vocabulary. The two forms below are equivalent:
    ///
    /// ```swift
    /// // Explicit Reader init
    /// return Reader { api in
    ///     api.fetch(id: id).asEffect()
    /// }
    ///
    /// // Shorthand — reads like Consequence.produce at the call site
    /// return .produce { api in
    ///     api.fetch(id: id).asEffect()
    /// }
    /// ```
    ///
    /// Full middleware example:
    ///
    /// ```swift
    /// let favMiddleware = Middleware<AppAction, AppState, API>.handle { action, _ in
    ///     guard case .toggleFavorite(let id) = action.action else { return .doNothing }
    ///     return .produce { api in
    ///         Effect.task { .favResult(await api.toggle(id: id)) }
    ///     }
    /// }
    /// ```
    public static func produce<Action: Sendable>(
        _ f: @escaping @Sendable (Environment) -> Effect<Action>
    ) -> Self where Output == Effect<Action> {
        Reader(f)
    }
}
