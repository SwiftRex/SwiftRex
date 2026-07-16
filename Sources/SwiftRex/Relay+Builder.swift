// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The fluent builder for `Relay.Scope`. Every step returns a `Relay.Scope` (no partial builder type):
// a static entry sets one axis (the others start `Absent`), and instance refiners replace one axis
// while keeping the rest. Bare declarations start from ``Relay/Empty``; inline (inside a `lift` call)
// leading-dot works because the host pins the generics.
//
//     store.projection(.action(prism).state(\.slice))
//     let scope = Relay.Empty.action(prism).state(\.slice).environment(\.childEnv)

extension Relay {
    /// The all-`Absent` scope — the bare-declaration entry point for the builder
    /// (`Relay.Empty.action(…)`), since a static on the generic `Relay.Scope` can't infer its own generics.
    public typealias Empty = Scope<ActionAxis.Absent, StateAxis.Absent, EnvironmentAxis.Absent>
}

// MARK: - Action entry + refiner (duplex `Prism` witness — subsumes every host)

extension Relay.Scope {
    /// Start a scope from the action axis (state/env `Absent`).
    public static func action<GA, LA>(
        _ prism: CoreFP.Prism<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(prism), state: .init(), environment: .init())
    }

    /// Start a scope from the action axis via a `\.case` key path.
    public static func action<GA, LA>(
        _ keyPath: PrismKeyPath<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(keyPath), state: .init(), environment: .init())
    }

    /// Replace the action axis, keeping state and environment.
    public func action<GA, LA>(
        _ prism: CoreFP.Prism<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(prism), state: state, environment: environment)
    }

    /// Replace the action axis via a `\.case` key path.
    public func action<GA, LA>(
        _ keyPath: PrismKeyPath<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(keyPath), state: state, environment: environment)
    }

    /// Start a scope from a `(preview, review)` closure pair — sugar for `Prism(preview:review:)`.
    public static func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?,
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(Prism(preview: preview, review: review)), state: .init(), environment: .init())
    }

    /// Replace the action axis with a `(preview, review)` closure pair.
    public func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?,
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(Prism(preview: preview, review: review)), state: state, environment: environment)
    }

    /// Start a scope from an extract-only `preview` closure → ``Relay/ActionAxis/Extracts`` (a
    /// reducer/behavior can extract; a projection, which needs to embed, won't accept it).
    public static func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?
    ) -> Relay.Scope<Relay.ActionAxis.Extracts<GA, LA>, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(preview), state: .init(), environment: .init())
    }

    /// Replace the action axis with an extract-only `preview` closure.
    public func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?
    ) -> Relay.Scope<Relay.ActionAxis.Extracts<GA, LA>, State, Environment> {
        .init(action: .init(preview), state: state, environment: environment)
    }

    /// Start a scope from an embed-only `review` closure → ``Relay/ActionAxis/Embeds`` (a projection
    /// dispatches; a reducer/behavior, which needs to extract, won't accept it).
    public static func action<GA, LA>(
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Embeds<GA, LA>, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(review), state: .init(), environment: .init())
    }

    /// Replace the action axis with an embed-only `review` closure.
    public func action<GA, LA>(
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Embeds<GA, LA>, State, Environment> {
        .init(action: .init(review), state: state, environment: environment)
    }
}

// MARK: - State entry + refiner

extension Relay.Scope {
    /// Start a scope from a total state key path (action/env `Absent`).
    public static func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS> & Sendable
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.ReadsWrites<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from an optional (affine) state key path.
    public static func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS?> & Sendable
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.Writes<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from a read-only state getter (action/env `Absent`) — serves projection/middleware.
    /// Unlabeled so it reads as a trailing closure: `.state { $0.slice }`.
    public static func state<GS, LS>(
        _ get: @escaping @Sendable (GS) -> LS
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.Reads<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(get), environment: .init())
    }

    /// Replace the state axis with a read-only getter.
    public func state<GS, LS>(
        _ get: @escaping @Sendable (GS) -> LS
    ) -> Relay.Scope<Action, Relay.StateAxis.Reads<GS, LS>, Environment> {
        .init(action: action, state: .init(get), environment: environment)
    }

    /// Start a scope from a total state `Lens` (action/env `Absent`).
    public static func state<GS, LS>(
        _ lens: Lens<GS, LS>
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.ReadsWrites<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(lens), environment: .init())
    }

    /// Replace the state axis with a total state key path.
    public func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Replace the state axis with a total state `Lens`.
    public func state<GS, LS>(
        _ lens: Lens<GS, LS>
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(lens), environment: environment)
    }

    /// Replace the state axis with an optional (affine) state key path.
    public func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS?> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Writes<GS, LS>, Environment> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Start a scope from a `(get, set)` closure pair — sugar for `Lens(get:set:)`.
    public static func state<GS, LS>(
        get: @escaping @Sendable (GS) -> LS,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.ReadsWrites<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(Lens(get: get, set: set)), environment: .init())
    }

    /// Replace the state axis with a `(get, set)` closure pair.
    public func state<GS, LS>(
        get: @escaping @Sendable (GS) -> LS,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(Lens(get: get, set: set)), environment: environment)
    }

    /// Start a scope from an **affine** `(preview, set)` closure pair → ``Relay/StateAxis/Writes`` — the
    /// optional-focus case (write-with-skip). Sugar for `AffineTraversal(preview:set:)`.
    public static func state<GS, LS>(
        preview: @escaping @Sendable (GS) -> LS?,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.Writes<GS, LS>, Relay.EnvironmentAxis.Absent> {
        .init(action: .init(), state: .init(AffineTraversal(preview: preview, set: set)), environment: .init())
    }

    /// Replace the state axis with an affine `(preview, set)` closure pair.
    public func state<GS, LS>(
        preview: @escaping @Sendable (GS) -> LS?,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Action, Relay.StateAxis.Writes<GS, LS>, Environment> {
        .init(action: action, state: .init(AffineTraversal(preview: preview, set: set)), environment: environment)
    }
}

// MARK: - Environment entry + refiner

extension Relay.Scope {
    /// Start a scope from the environment axis (action/state `Absent`).
    public static func environment<GE, LE>(
        _ narrow: @escaping @Sendable (GE) -> LE
    ) -> Relay.Scope<Relay.ActionAxis.Absent, Relay.StateAxis.Absent, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: .init(), state: .init(), environment: .init(narrow))
    }

    /// Replace the environment axis with a narrowing closure.
    public func environment<GE, LE>(
        _ narrow: @escaping @Sendable (GE) -> LE
    ) -> Relay.Scope<Action, State, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: action, state: state, environment: .init(narrow))
    }

    /// Replace the environment axis with a narrowing key path.
    public func environment<GE, LE>(
        _ keyPath: KeyPath<GE, LE> & Sendable
    ) -> Relay.Scope<Action, State, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: action, state: state, environment: .init(keyPath))
    }
}
