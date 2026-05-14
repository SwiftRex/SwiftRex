import CoreFP
import DataStructure

// MARK: - Reader: Semigroup / Monoid (@retroactive until luizmb/FP#40 ships)
//
// A Reader whose output is a Semigroup/Monoid is itself one under pointwise combination.
// The conformance lives here temporarily via @retroactive; once FP ships it natively,
// these two extensions can be removed.

extension Reader: @retroactive Semigroup where Output: Semigroup {
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        Reader { env in .combine(lhs.runReader(env), rhs.runReader(env)) }
    }
}

extension Reader: @retroactive Monoid where Output: Monoid {
    public static var identity: Self { .pure(.identity) }
}

// MARK: - SwiftRex bridge: .doNothing for Effect pipelines
//
// `.doNothing` is SwiftRex vocabulary for the Monoid identity of
// `Reader<Environment, Effect<Action>>` — produce no side-effects for any environment.
// It reads naturally at Middleware and Behavior call sites:
//
//   guard case .fetchData(let q) = action.action else { return .doNothing }

extension Reader where Output: Monoid {
    /// Produces no effect for any environment.
    ///
    /// The idiomatic SwiftRex way to early-exit a ``Middleware/handle`` or
    /// ``Behavior/handle`` closure when an action is not relevant:
    ///
    /// ```swift
    /// let fetchMiddleware = Middleware<AppAction, AppState, API>.handle { action, _ in
    ///     guard case .fetchData(let query) = action.action else { return .doNothing }
    ///     return Reader { api in
    ///         Effect.task { try await api.search(query) }
    ///             .map(AppAction.searchResult)
    ///     }
    /// }
    /// ```
    ///
    /// Equivalent to `Reader { _ in .empty }` but communicates intent clearly.
    public static var doNothing: Self { .identity }
}
