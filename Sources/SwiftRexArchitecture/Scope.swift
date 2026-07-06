// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import CoreFP
    import SwiftRex

    /// The wiring that scopes a child ``Feature`` into a parent (app) store — declared **once** and used
    /// for both behavior composition **and** navigation.
    ///
    /// A `Scope` captures how a child embeds into the parent's `(GlobalAction, GlobalState,
    /// GlobalEnvironment)`: the action prism, the state key path, and the environment-narrowing. From the
    /// child feature it derives:
    /// - ``behavior`` — the child's behavior lifted to the global types (register it in the app behavior);
    /// - ``view(from:world:)`` — the child's view, built with the scoped store and narrowed environment.
    ///   This resolves the navigation crux: an environment-free view body never builds a child itself; a
    ///   router calls this.
    ///
    /// ## Compile-time proof of wiring
    ///
    /// Constructing a `Scope` is the proof the feature is wired: it won't type-check unless the global
    /// state slot, action case, and env-narrowing line up with the child feature's own `(Action, State,
    /// Environment)`. Forget one and you get a compile error at the literal.
    ///
    /// ```swift
    /// let detailScope = Scope(Detail.self, action: \.detail, state: \.detail, environment: \.detailEnv)
    /// detailScope.behavior                          // Behavior<AppAction, AppState, World>
    /// detailScope.view(from: store, world: world)   // Detail's view, env supplied — for a router switch
    /// ```
    ///
    /// This `Scope` is for **present-state** children (a sibling slice always in state — the shape a tab,
    /// split pane, or a route whose state lives alongside uses). An **optional/modal** child (`State?`)
    /// registers its behavior with `liftOptional` (see the navigation reducers) and has its view
    /// hand-wired in the router via a store `item` projection.
    public struct Scope<
        GlobalAction: Sendable & Prismatic,
        GlobalState: Sendable,
        GlobalEnvironment: Sendable,
        F: Feature
    >: Sendable {
        /// The child behavior lifted to the global `(Action, State, Environment)` — homogeneous across
        /// every scope, so a whole app's behaviors fold with ``Behavior/combine(_:)-(Array)``.
        public let behavior: Behavior<GlobalAction, GlobalState, GlobalEnvironment>

        private let action: PrismKeyPath<GlobalAction, F.Action>
        private let state: KeyPath<GlobalState, F.State>
        private let narrowEnvironment: @Sendable (GlobalEnvironment) -> F.Environment

        /// Scopes a child feature whose state is a present sibling slice.
        public init(
            _ feature: F.Type,
            action: PrismKeyPath<GlobalAction, F.Action>,
            state: WritableKeyPath<GlobalState, F.State>,
            environment: @escaping @Sendable (GlobalEnvironment) -> F.Environment
        ) {
            self.action = action
            self.state = state
            narrowEnvironment = environment
            behavior = F.behavior().lift(action: action, state: state, environment: environment)
        }

        /// Env-as-key-path convenience.
        public init(
            _ feature: F.Type,
            action: PrismKeyPath<GlobalAction, F.Action>,
            state: WritableKeyPath<GlobalState, F.State>,
            environment: KeyPath<GlobalEnvironment, F.Environment> & Sendable
        ) {
            self.init(feature, action: action, state: state, environment: { $0[keyPath: environment] })
        }

        /// Builds the child feature's view from the scoped store and narrowed environment — the WHAT of
        /// navigation. Call it from a router's `@ViewBuilder view(for:)` switch; the environment comes
        /// from the world the router holds, never from the (environment-free) presenting view body.
        @MainActor
        public func view(from store: any StoreType<GlobalAction, GlobalState>, world: GlobalEnvironment) -> F.Body {
            F.view(store: store.projection(action: action, state: state), environment: narrowEnvironment(world))
        }
    }
#endif
