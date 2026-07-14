// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex
    import SwiftUI

    /// The domain triad every feature shares — its `Action`, `State`, and `Environment` — with no
    /// capability attached. Both ``HasBehavior`` and ``ViewFactory`` refine it, so the liftable wiring
    /// (``Scope``) can be expressed over the triad alone: a `Scope` lifts whatever the child provides —
    /// a behavior, a view, or both — because all three only need the triad to embed into a parent.
    ///
    /// It is the type-level *recipe* (`Environment` not yet applied), the dual of ``StoreType`` — the
    /// runtime surface where `Environment` has been applied and erased, leaving only `(Action, State)`.
    public protocol FeatureDomain {
        /// The feature's action type.
        associatedtype Action: Sendable
        /// The feature's state type.
        associatedtype State: Sendable
        /// The feature's environment (dependencies) type.
        associatedtype Environment: Sendable
    }

    /// A feature that produces a ``Behavior`` — the composable, liftable behavior capability. A
    /// logic-only feature (no view) can conform to just this.
    public protocol HasBehavior: FeatureDomain {
        /// The feature's behavior — its reducer/effects/supervisor, composed once.
        static func behavior() -> Behavior<Action, State, Environment>
    }

    /// A feature that builds its SwiftUI view — the view capability.
    ///
    /// `view` takes `any StoreType<Action, State>` (a concrete existential), **not** a generic
    /// `some StoreType`: a generic method returning `some View` cannot bind the ``Body`` associated
    /// type; the existential can. A `Store` or `StoreProjection` boxes into it, so callers are unaffected.
    public protocol ViewFactory: FeatureDomain {
        /// The concrete view type produced — inferred from `view`'s `some View` result.
        associatedtype Body: View

        /// Builds the feature's view from the (already scoped) store and environment — the caller
        /// supplies both, resolving the navigation crux (an environment-free view body never builds this).
        @MainActor static func view(store: any StoreType<Action, State>, environment: Environment) -> Body
    }

    /// A full feature: it both produces a ``Behavior`` and builds a view — what a ``Scope`` needs to
    /// drive **both** behavior composition and navigation from one declaration.
    ///
    /// It **re-declares** both requirements (rather than only inheriting them). That is what lets a
    /// conformer's associated types infer through the combined protocol — inheriting alone does not.
    /// It exposes only the liftable/viewable surface, never `ViewState`/`ViewAction`.
    public protocol Feature: HasBehavior, ViewFactory {
        static func behavior() -> Behavior<Action, State, Environment>
        @MainActor static func view(store: any StoreType<Action, State>, environment: Environment) -> Body
    }
#endif
