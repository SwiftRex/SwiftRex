// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex

    /// A single registration point for an app's scoped feature behaviors.
    ///
    /// Each ``Scope`` is generic over its child feature, so scopes are heterogeneous and can't share one
    /// array — but their ``Scope/behavior`` is homogeneous (`Behavior<GlobalAction, GlobalState,
    /// GlobalEnvironment>`). List those; ``behavior`` folds them into one. Declaring a scope and passing
    /// its `.behavior` here is the single place a feature's behavior is registered:
    ///
    /// ```swift
    /// let appBehavior = Scopes(homeScope.behavior, detailScope.behavior, navigationReducer).behavior
    /// let store = Store(initial: .init(), behavior: appBehavior, environment: world)
    /// ```
    ///
    /// The same scope values feed a hand-written router's `@ViewBuilder view(for:)` switch (via
    /// ``Scope/view(from:world:)``), so behavior registration and navigation share one source of truth.
    public struct Scopes<GlobalAction: Sendable, GlobalState: Sendable, GlobalEnvironment: Sendable>: Sendable {
        /// The combined behavior of every registered scope (plus any extra behaviors passed in) — fold
        /// this into the store.
        public let behavior: Behavior<GlobalAction, GlobalState, GlobalEnvironment>

        /// Registers scope behaviors (and any extra behaviors, e.g. a navigation reducer or logging).
        public init(_ behaviors: Behavior<GlobalAction, GlobalState, GlobalEnvironment>...) {
            behavior = .combine(behaviors)
        }

        /// Registers scope behaviors (array form).
        public init(_ behaviors: [Behavior<GlobalAction, GlobalState, GlobalEnvironment>]) {
            behavior = .combine(behaviors)
        }
    }
#endif
