// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex
    import SwiftUI

    /// The domain triad every feature shares — its `Action`, `State`, and `Environment`. It is the
    /// `SwiftRex.Architecture` spelling of the core ``SwiftRex/Rig`` (a ``SwiftRex/Transceiver`` that also
    /// reaches the world): both ``HasBehavior`` and ``ViewFactory`` refine it, so the liftable wiring
    /// (``Gateway``) can be expressed over the triad alone — a `Gateway` lifts whatever the child
    /// provides, a behavior, a view, or both.
    public typealias FeatureDomain = Rig

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

    /// A full feature: it both produces a ``Behavior`` and builds a view — what a ``Gateway`` needs to
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
