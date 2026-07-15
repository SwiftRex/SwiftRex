// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import CoreFP
    import SwiftRex

    /// The env-aware, full-duplex link that embeds a child ``Rig`` into a parent (app) one — declared
    /// **once** and used for both behavior composition **and** navigation. It is the ``Relay``'s
    /// counterpart that also carries the world: where a `Relay` re-indexes a `(Action, State)`
    /// ``Transceiver`` with one movement per lane, a `Gateway` runs **both ways on both lanes** plus an
    /// environment narrow — the feature *lift*.
    ///
    /// A `Gateway` is the morphism `Local ↪ Global` between two ``Rig``s — how the child embeds into the
    /// parent. Its three pieces are the three axes' variances: a **prism** on action (extract inbound,
    /// embed outbound), a **lens** on state (get + set), and a contravariant **function** on environment
    /// (narrow `Global.Environment → Local.Environment`). Given that morphism it **lifts whatever the
    /// child provides**:
    /// - ``behavior`` — available when the child is ``HasBehavior``: its behavior lifted to the global
    ///   types (register it in the app behavior);
    /// - ``view(from:world:)`` — available when the child is ``ViewFactory``: its view built with the
    ///   scoped store and narrowed environment. This resolves the navigation crux — an environment-free
    ///   view body never builds a child itself; a router calls this.
    ///
    /// A full ``Feature`` (both) exposes both; a logic-only capability (``HasBehavior`` only, e.g. an
    /// injected system-event source) exposes just `behavior`; a view-only type exposes just `view`.
    /// Accessing a capability the child doesn't provide simply won't compile.
    ///
    /// ## Compile-time proof of wiring
    ///
    /// Constructing a `Gateway` is the proof the feature is wired: it won't type-check unless the global
    /// state slot, action case, and env-narrowing line up with the child's own `(Action, State,
    /// Environment)`. Forget one and you get a compile error at the literal.
    ///
    /// ```swift
    /// // Global is the parent's Rig (AppFeature, or a module for a nested router).
    /// let detail = Gateway<AppFeature, Detail>(Detail.self, action: \.detail, state: \.detail, environment: \.detailEnv)
    /// detail.behavior                          // Behavior<AppFeature.Action, .State, .Environment> (Detail: HasBehavior)
    /// detail.view(from: store, world: world)   // Detail's view, env supplied (Detail: ViewFactory)
    /// ```
    ///
    /// This `Gateway` is for **present-state** children (a sibling slice always in state — the shape a
    /// tab, split pane, or a route whose state lives alongside uses). An **optional/modal** child
    /// (`State?`) registers its behavior with `liftOptional` (see the navigation reducers) and has its
    /// view hand-wired in the router via a store `item` projection.
    public struct Gateway<Global: Rig, Local: Rig>: Sendable where Global.Action: Prismatic {
        fileprivate let action: PrismKeyPath<Global.Action, Local.Action>
        fileprivate let state: WritableKeyPath<Global.State, Local.State>
        fileprivate let narrowEnvironment: @Sendable (Global.Environment) -> Local.Environment

        /// Embeds a child feature whose state is a present sibling slice of the parent.
        public init(
            _ local: Local.Type,
            action: PrismKeyPath<Global.Action, Local.Action>,
            state: WritableKeyPath<Global.State, Local.State>,
            environment: @escaping @Sendable (Global.Environment) -> Local.Environment
        ) {
            self.action = action
            self.state = state
            narrowEnvironment = environment
        }

        /// Env-as-key-path convenience.
        public init(
            _ local: Local.Type,
            action: PrismKeyPath<Global.Action, Local.Action>,
            state: WritableKeyPath<Global.State, Local.State>,
            environment: KeyPath<Global.Environment, Local.Environment> & Sendable
        ) {
            self.init(local, action: action, state: state, environment: { $0[keyPath: environment] })
        }
    }

    // The behavior capability — present only when the child supplies one.
    extension Gateway where Local: HasBehavior {
        /// The child behavior lifted to the parent's `(Action, State, Environment)` — homogeneous across
        /// every gateway of the same `Global`, so a whole app's behaviors fold with
        /// ``Behavior/combine(_:)-(Array)``.
        public var behavior: Behavior<Global.Action, Global.State, Global.Environment> {
            Local.behavior().lift(action: action, state: state, environment: narrowEnvironment)
        }
    }

    // The view capability — present only when the child supplies one.
    extension Gateway where Local: ViewFactory {
        /// Builds the child feature's view from the scoped store and narrowed environment — the WHAT of
        /// navigation. Call it from a router's `@ViewBuilder view(for:)` switch; the environment comes
        /// from the world the router holds, never from the (environment-free) presenting view body.
        @MainActor
        public func view(from store: any StoreType<Global.Action, Global.State>, world: Global.Environment) -> Local.Body {
            Local.view(store: store.projection(action: action, state: state), environment: narrowEnvironment(world))
        }
    }
#endif
