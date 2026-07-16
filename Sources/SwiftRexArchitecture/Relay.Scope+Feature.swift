// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex
    import SwiftUI

    // The feature-lift capabilities on ``Relay/Scope`` — what the old `Gateway` provided, now folded onto
    // the one carrier. A scope that re-indexes a feature's `(Action, State, Environment)` into a parent
    // (its lanes' *local* types match the feature's) drives **both** the app behavior and the router view
    // from one declared value:
    //
    //     let movies = Relay.Empty
    //         .action(AppAction.prism.movies).state(\AppState.movies).environment(\.moviesEnv)
    //     movies.behavior(of: MoviesFeature.self)                  // fold into the app behavior
    //     movies.view(of: MoviesFeature.self, from: store, world: world)   // build the screen in the router

    extension Relay.Scope where
        Action: Relay.ActionAxis.ExtractsProtocol & Relay.ActionAxis.EmbedsProtocol,
        State: Relay.StateAxis.WritesProtocol,
        Environment: Relay.EnvironmentAxis.NarrowsProtocol {
        /// Lift `feature`'s behavior through this scope into the parent `(Action, State, Environment)`.
        /// Available when the child provides a ``HasBehavior`` and this scope's lanes match its local types.
        public func behavior<F: HasBehavior>(
            of feature: F.Type
        ) -> Behavior<Action.G, State.G, Environment.G>
        where F.Action == Action.L, F.State == State.L, F.Environment == Environment.L {
            F.behavior().lift(self)
        }
    }

    extension Relay.Scope where
        Action: Relay.ActionAxis.EmbedsProtocol,
        State: Relay.StateAxis.ReadsProtocol,
        Environment: Relay.EnvironmentAxis.NarrowsProtocol {
        /// Build `feature`'s view from this scope — projecting `store` and narrowing `world` to the child's
        /// environment. The WHAT of navigation: a router calls this; the environment-free view body never
        /// builds a child. Available when the child is a ``ViewFactory``.
        @MainActor
        public func view<F: ViewFactory>(
            of feature: F.Type,
            from store: any StoreType<Action.G, State.G>,
            world: Environment.G
        ) -> F.Body
        where F.Action == Action.L, F.State == State.L, F.Environment == Environment.L {
            F.view(store: store.projection(self), environment: environment.narrow(world))
        }
    }
#endif
