// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import SwiftRex
    import SwiftRexSwiftUI
    import SwiftUI

    // The feature-lift capabilities on ``Relay/Scope``. A scope that re-indexes a feature's `(Action, State, Environment)` into a parent
    // (its lanes' *local* types match the feature's) drives **both** the app behavior and the router view
    // from one declared value:
    //
    //     static let movies = ScopeOf<AppFeature>
    //         .action(\.movies).state(\.movies).environment(\.moviesEnv)
    //     movies.behavior(of: MoviesFeature.self) // fold into the app behavior
    //     movies.view(of: MoviesFeature.self, from: store, world: world) // build the screen in the router
    //
    // The coherence constraints (`…Strategy.Global == …`) restate what the only `Scope` initializer
    // already guarantees — they give the compiler the same-type knowledge locally.

    extension Relay.Scope where
        ActionStrategy: Relay.ActionAxis.ExtractsProtocol & Relay.ActionAxis.EmbedsProtocol,
        StateStrategy: Relay.StateAxis.WritesProtocol,
        EnvironmentStrategy: Relay.EnvironmentAxis.NarrowsProtocol,
        ActionStrategy.Global == Action,
        StateStrategy.Global == State,
        EnvironmentStrategy.Global == Environment {
        /// Lift `feature`'s behavior through this scope into the parent `(Action, State, Environment)`.
        /// Available when the child provides a ``HasBehavior`` and this scope's lanes match its local types.
        public func behavior<F: HasBehavior>(
            of feature: F.Type
        ) -> Behavior<Action, State, Environment>
        where F.Action == ActionStrategy.Local, F.State == StateStrategy.Local, F.Environment == EnvironmentStrategy.Local {
            F.behavior().lift(self)
        }
    }

    extension Relay.Scope where
        ActionStrategy: Relay.ActionAxis.EmbedsProtocol,
        StateStrategy: Relay.StateAxis.ReadsProtocol,
        EnvironmentStrategy: Relay.EnvironmentAxis.NarrowsProtocol,
        ActionStrategy.Global == Action,
        StateStrategy.Global == State,
        EnvironmentStrategy.Global == Environment {
        /// Build `feature`'s view from this scope — projecting `store` and narrowing `world` to the child's
        /// environment. The WHAT of navigation: a router calls this; the environment-free view body never
        /// builds a child. Available when the child is a ``ViewFactory``.
        @MainActor
        public func view<F: ViewFactory>(
            of feature: F.Type,
            from store: any StoreType<Action, State>,
            world: Environment
        ) -> F.Body
        where F.Action == ActionStrategy.Local, F.State == StateStrategy.Local, F.Environment == EnvironmentStrategy.Local {
            F.view(store: store.projection(action: action.review, state: state.get), environment: environment.narrow(world))
        }
    }

    extension Relay.Scope where
        ActionStrategy: Relay.ActionAxis.EmbedsProtocol,
        StateStrategy: Relay.StateAxis.WritesProtocol,
        EnvironmentStrategy: Relay.EnvironmentAxis.NarrowsProtocol,
        ActionStrategy.Global == Action,
        StateStrategy.Global == State,
        EnvironmentStrategy.Global == Environment {
        /// Build `feature`'s view from this scope's **optional** slot — `nil` while the slot is absent. The same
        /// declared scope that lifts the child's behavior over the optional (`.state(\.detail)` on a `Detail?`). Reads
        /// the slot's presence on `viewStore` (the caller depends on that edge only) and hands the feature a pure stage
        /// that holds its last value while the screen animates away; the feature's view keeps its own view store.
        ///
        /// ```swift
        /// if let detail = AppScopes.detail.view(of: DetailFeature.self, from: viewStore, world: world) { detail }
        /// ```
        @MainActor
        public func view<F: ViewFactory>(
            of feature: F.Type,
            from viewStore: ViewStore<Action, State>,
            world: Environment,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> F.Body?
        where F.Action == ActionStrategy.Local, F.State == StateStrategy.Local, F.Environment == EnvironmentStrategy.Local {
            viewStore.traverse(self, fileID: fileID, line: line, column: column)
                .map { F.view(store: $0, environment: environment.narrow(world)) }
        }
    }

    extension Relay.Scope where
        ActionStrategy: Relay.ActionAxis.EmbedsProtocol,
        StateStrategy: Relay.StateAxis.ReadsProtocol,
        EnvironmentStrategy: Relay.EnvironmentAxis.NarrowsProtocol,
        ActionStrategy.Global == Action,
        StateStrategy.Global == State,
        EnvironmentStrategy.Global == Environment {
        /// Build `feature`'s view from this scope's ``Presentation`` slot — present while `presented` **or**
        /// `dismissing`, so the screen stays alive and steady while SwiftUI animates it out. The same declared scope
        /// `liftPresentation` lifts the child's behavior through.
        ///
        /// ```swift
        /// .sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
        ///     AppScopes.editor.view(of: EditorFeature.self, from: viewStore, world: world)
        /// }
        /// ```
        @MainActor
        public func view<F: ViewFactory, ChildAction>(
            of feature: F.Type,
            from viewStore: ViewStore<Action, State>,
            world: Environment,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> F.Body?
        where ActionStrategy.Local == PresentationAction<ChildAction>, F.Action == ChildAction,
            StateStrategy.Local == Presentation<F.State>, F.Environment == EnvironmentStrategy.Local {
            let childLane = Relay.ActionAxis.Embeds<Action, ChildAction> { action.review(.child($0)) }
            let child = Relay.Scope<Action, Relay.ActionAxis.Embeds<Action, ChildAction>, State, StateStrategy, Never, Relay.Absurd<Never>>(
                action: childLane,
                state: state
            )
            return viewStore.traverse(child, fileID: fileID, line: line, column: column)
                .map { F.view(store: $0, environment: environment.narrow(world)) }
        }
    }
#endif
