// SPDX-License-Identifier: Apache-2.0

import CoreFP

// `ScopeOf<Global>` — the **pivot** builder for *declared* scopes. Name the app's `Rig` once and every bare
// key path roots at its `Action`/`State`/`Environment`; the environment closure's parameter is inferred. It
// carries `Global` **only through the chain** (so later steps can still root bare key paths) and terminates
// into a plain ``Relay/Scope`` via `.scope` — the pivot never lands on the value or on a host, so it never
// reintroduces the "Global can't be inferred" problem (you *name* it, nothing infers it).
//
//     public static let stacks = ScopeOf<AppFeature>          // AppFeature: Rig = (AppAction, AppState, World)
//         .action(\.stacks).state(\.stacks).environment { $0.badge }
//
// vs the pivot-less spelling, which must spell out every root because there's nothing to infer against:
//
//     Relay.Scope.identity.action(AppAction.prism.stacks).state(\AppState.stacks).environment { (w: World) in … }

extension Relay {
    /// A `Global`-carrying scope builder (see ``ScopeOf``). Reach the built lane bundle with ``scope``.
    public struct ScopeBuilder<
        Global: Rig,
        Action: ActionAxis.Strategy,
        State: StateAxis.Strategy,
        Environment: EnvironmentAxis.Strategy
    >: Sendable {
        /// The plain lane bundle — `Global` does not appear here, so every host accepts it unchanged.
        public let scope: Scope<Action, State, Environment>
        init(_ scope: Scope<Action, State, Environment>) { self.scope = scope }
    }

    /// Entry to the pivot builder: `ScopeOf<AppFeature>` starts an all-``Relay/Identity`` scope whose bare
    /// key paths root at `AppFeature`'s `Action`/`State`/`Environment`.
    public typealias ScopeOf<Global: Rig> = ScopeBuilder<Global, Identity, Identity, Identity>
}

// MARK: - Action — entry (static, from the all-Identity pivot) + refiner (where the action axis is Identity)

extension Relay.ScopeBuilder where Action == Relay.Identity, State == Relay.Identity, Environment == Relay.Identity {
    /// Start from the action axis via a `\.case` key path rooted at `Global.Action`.
    public static func action<LA>(
        _ keyPath: PrismKeyPath<Global.Action, LA>
    ) -> Relay.ScopeBuilder<Global, Relay.ActionAxis.Prism<Global.Action, LA>, Relay.Identity, Relay.Identity> {
        .init(.init(action: .init(keyPath), state: .init(), environment: .init()))
    }

    /// Start from the action axis via an explicit `Prism` over `Global.Action`.
    public static func action<LA>(
        _ prism: CoreFP.Prism<Global.Action, LA>
    ) -> Relay.ScopeBuilder<Global, Relay.ActionAxis.Prism<Global.Action, LA>, Relay.Identity, Relay.Identity> {
        .init(.init(action: .init(prism), state: .init(), environment: .init()))
    }
}

extension Relay.ScopeBuilder where Action == Relay.Identity {
    /// Replace the pass-through action axis via a `\.case` key path rooted at `Global.Action`.
    public func action<LA>(
        _ keyPath: PrismKeyPath<Global.Action, LA>
    ) -> Relay.ScopeBuilder<Global, Relay.ActionAxis.Prism<Global.Action, LA>, State, Environment> {
        .init(.init(action: .init(keyPath), state: scope.state, environment: scope.environment))
    }

    /// Replace the pass-through action axis via an explicit `Prism` over `Global.Action`.
    public func action<LA>(
        _ prism: CoreFP.Prism<Global.Action, LA>
    ) -> Relay.ScopeBuilder<Global, Relay.ActionAxis.Prism<Global.Action, LA>, State, Environment> {
        .init(.init(action: .init(prism), state: scope.state, environment: scope.environment))
    }
}

// MARK: - State — entry + refiner (where the state axis is Identity), rooted at Global.State

extension Relay.ScopeBuilder where Action == Relay.Identity, State == Relay.Identity, Environment == Relay.Identity {
    /// Start from a total state key path rooted at `Global.State`.
    public static func state<LS>(
        _ keyPath: WritableKeyPath<Global.State, LS> & Sendable
    ) -> Relay.ScopeBuilder<Global, Relay.Identity, Relay.StateAxis.ReadsWrites<Global.State, LS>, Relay.Identity> {
        .init(.init(action: .init(), state: .init(keyPath), environment: .init()))
    }

    /// Start from an optional (affine) state key path rooted at `Global.State`.
    public static func state<LS>(
        _ keyPath: WritableKeyPath<Global.State, LS?> & Sendable
    ) -> Relay.ScopeBuilder<Global, Relay.Identity, Relay.StateAxis.Writes<Global.State, LS>, Relay.Identity> {
        .init(.init(action: .init(), state: .init(keyPath), environment: .init()))
    }
}

extension Relay.ScopeBuilder where State == Relay.Identity {
    /// Replace the pass-through state axis via a total state key path rooted at `Global.State`.
    public func state<LS>(
        _ keyPath: WritableKeyPath<Global.State, LS> & Sendable
    ) -> Relay.ScopeBuilder<Global, Action, Relay.StateAxis.ReadsWrites<Global.State, LS>, Environment> {
        .init(.init(action: scope.action, state: .init(keyPath), environment: scope.environment))
    }

    /// Replace the pass-through state axis via an optional (affine) state key path rooted at `Global.State`.
    public func state<LS>(
        _ keyPath: WritableKeyPath<Global.State, LS?> & Sendable
    ) -> Relay.ScopeBuilder<Global, Action, Relay.StateAxis.Writes<Global.State, LS>, Environment> {
        .init(.init(action: scope.action, state: .init(keyPath), environment: scope.environment))
    }

    /// Replace the pass-through state axis via a `Lens` over `Global.State`.
    public func state<LS>(
        _ lens: Lens<Global.State, LS>
    ) -> Relay.ScopeBuilder<Global, Action, Relay.StateAxis.ReadsWrites<Global.State, LS>, Environment> {
        .init(.init(action: scope.action, state: .init(lens), environment: scope.environment))
    }

    /// Replace the pass-through state axis via a read-only getter over `Global.State`.
    public func state<LS>(
        _ get: @escaping @Sendable (Global.State) -> LS
    ) -> Relay.ScopeBuilder<Global, Action, Relay.StateAxis.Reads<Global.State, LS>, Environment> {
        .init(.init(action: scope.action, state: .init(get), environment: scope.environment))
    }
}

// MARK: - Environment — entry + refiner (where the environment axis is Identity), from Global.Environment

extension Relay.ScopeBuilder where Action == Relay.Identity, State == Relay.Identity, Environment == Relay.Identity {
    /// Start from an environment narrow over `Global.Environment`.
    public static func environment<LE>(
        _ narrow: @escaping @Sendable (Global.Environment) -> LE
    ) -> Relay.ScopeBuilder<Global, Relay.Identity, Relay.Identity, Relay.EnvironmentAxis.Narrows<Global.Environment, LE>> {
        .init(.init(action: .init(), state: .init(), environment: .init(narrow)))
    }
}

extension Relay.ScopeBuilder where Environment == Relay.Identity {
    /// Replace the pass-through environment axis with a narrowing closure over `Global.Environment`.
    public func environment<LE>(
        _ narrow: @escaping @Sendable (Global.Environment) -> LE
    ) -> Relay.ScopeBuilder<Global, Action, State, Relay.EnvironmentAxis.Narrows<Global.Environment, LE>> {
        .init(.init(action: scope.action, state: scope.state, environment: .init(narrow)))
    }

    /// Replace the pass-through environment axis with a narrowing key path over `Global.Environment`.
    public func environment<LE>(
        _ keyPath: KeyPath<Global.Environment, LE> & Sendable
    ) -> Relay.ScopeBuilder<Global, Action, State, Relay.EnvironmentAxis.Narrows<Global.Environment, LE>> {
        .init(.init(action: scope.action, state: scope.state, environment: .init(keyPath)))
    }
}
