import CoreFP
import DataStructure

// MARK: - Reader: Semigroup / Monoid
//
// A Reader whose output is a Semigroup/Monoid is itself a Semigroup/Monoid under
// pointwise combination: `combine(r1, r2)` runs both readers on the same environment
// and combines their outputs.
//
// In the Middleware context (`Reader<Environment, Effect<Action>>`), this gives the
// natural "run both effects" Semigroup and the "do nothing" Monoid identity.

extension Reader: @retroactive Semigroup where Output: Semigroup {
    /// Combines two `Reader`s by running both on the same environment and combining
    /// their outputs via the output's `Semigroup.combine`.
    ///
    /// ```swift
    /// let combined = Reader.combine(logEffect, fetchEffect)
    /// // equivalent to: Reader { env in .combine(logEffect.run(env), fetchEffect.run(env)) }
    /// ```
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        Reader { env in .combine(lhs.runReader(env), rhs.runReader(env)) }
    }
}

extension Reader: @retroactive Monoid where Output: Monoid {
    /// The identity `Reader`: ignores its environment and returns `Output.identity`.
    ///
    /// In a `Middleware<Action, State, Environment>` returning
    /// `Reader<Environment, Effect<Action>>`, this is "produce no effects":
    ///
    /// ```swift
    /// let m = Middleware<AppAction, AppState, AppEnv>.handle { action, _ in
    ///     guard case .fetchData(let query) = action.action else { return .doNothing }
    ///     return Reader { env in Effect.task { await env.api.fetch(query) } }
    /// }
    /// ```
    public static var identity: Self { Reader { _ in .identity } }
}

// MARK: - Expressive alias for Middleware/Behavior return sites

extension Reader where Output: Monoid {
    /// Produces no output — the `Output` Monoid's identity for every environment.
    ///
    /// A named alias for ``identity`` that reads more naturally at Middleware and Behavior
    /// call sites where the output is `Effect<Action>`:
    ///
    /// ```swift
    /// // Instead of:
    /// return Reader { _ in .empty }
    ///
    /// // Write:
    /// return .doNothing
    /// ```
    public static var doNothing: Self { .identity }
}
