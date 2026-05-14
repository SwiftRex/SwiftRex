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
