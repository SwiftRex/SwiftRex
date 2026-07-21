// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The fluent builder for `Relay.Scope`. Every step returns a `Relay.Scope` (no partial builder type):
//   - a **static factory** starts a scope by setting one axis to a real ``Relay/…Axis/LiftingProtocol``
//     witness; the other two start as pass-through ``Relay/Identity``. Static entries exist ONLY for real
//     witnesses — you never construct an `Identity` or `Absurd` via a factory.
//   - an **instance refiner** replaces one axis while keeping the others; it is gated
//     `where ThatAxis == Relay.Identity`, so you may specialise an axis exactly once. `.action().state()`
//     works; `.state().state()` does not (state is no longer `Identity`), and a sealed ``Relay/Absurd``
//     axis offers no refiner at all — enforced by conformance, no `@available`.
//
// Bare declarations start from ``Relay/Scope/identity``; inline (inside a `lift`/`projection` call) the leading-dot
// works because the host pins the generics.
//
//     store.projection(.action(prism).state(\.slice))
//     let scope = Relay.Scope.identity.action(prism).state(\.slice).environment(\.childEnv)

extension Relay.Scope where Action == Relay.Identity, State == Relay.Identity, Environment == Relay.Identity {
    /// The identity re-index — the all-``Relay/Identity`` scope **value** (`Global → Global` on every axis),
    /// the bare-declaration entry point for the builder (`Relay.Scope.identity.action(…)`). It's a value, not
    /// a type, so the first `.action`/`.state`/`.environment` resolves to an **instance** refiner that keeps
    /// the un-set axes ``Relay/Identity`` concretely — where a static entry would leave the un-set (now
    /// context-adaptive) axes un-inferable outside a host call.
    public static var identity: Self {
        .init(action: .init(), state: .init(), environment: .init())
    }
}

// MARK: - Action axis — static factories (entry)
//
// The un-set state/env axes are a constructible generic (``Relay/AxisDefault``): a lift chain fills them
// ``Relay/Identity`` (so `.state`/`.environment` can refine), an action-only `.on` seals them
// ``Relay/Absurd`` — the choice is made by the host's expected type, one entry serving both.

extension Relay.Scope {
    /// Start a scope from the action axis via a `Prism` (duplex — serves every host).
    public static func action<GA, LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ prism: CoreFP.Prism<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, S, E> {
        .init(action: .init(prism), state: .init(), environment: .init())
    }

    /// Start a scope from the action axis via a `\.case` key path.
    public static func action<GA, LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: PrismKeyPath<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, S, E> {
        .init(action: .init(keyPath), state: .init(), environment: .init())
    }

    /// Start a scope from a `(preview, review)` closure pair — sugar for `Prism(preview:review:)`.
    public static func action<GA, LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (GA) -> LA?,
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, S, E> {
        .init(action: .init(Prism(preview: preview, review: review)), state: .init(), environment: .init())
    }

    /// Start a scope from an extract-only `preview` closure → ``Relay/ActionAxis/Extracts`` (a
    /// reducer/behavior can extract; a projection, which needs to embed, won't accept it).
    public static func action<GA, LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (GA) -> LA?
    ) -> Relay.Scope<Relay.ActionAxis.Extracts<GA, LA>, S, E> {
        .init(action: .init(preview), state: .init(), environment: .init())
    }

    /// Start a scope from an embed-only `review` closure → ``Relay/ActionAxis/Embeds`` (a projection
    /// dispatches; a reducer/behavior, which needs to extract, won't accept it).
    public static func action<GA, LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Embeds<GA, LA>, S, E> {
        .init(action: .init(review), state: .init(), environment: .init())
    }
}

// MARK: - Action axis — instance refiners (only where the action axis is still `Identity`)

extension Relay.Scope where Action == Relay.Identity {
    /// Replace the pass-through action axis via a `Prism`, keeping state and environment.
    public func action<GA, LA>(
        _ prism: CoreFP.Prism<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(prism), state: state, environment: environment)
    }

    /// Replace the pass-through action axis via a `\.case` key path.
    public func action<GA, LA>(
        _ keyPath: PrismKeyPath<GA, LA>
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(keyPath), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with a `(preview, review)` closure pair.
    public func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?,
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Prism<GA, LA>, State, Environment> {
        .init(action: .init(Prism(preview: preview, review: review)), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with an extract-only `preview` closure.
    public func action<GA, LA>(
        preview: @escaping @Sendable (GA) -> LA?
    ) -> Relay.Scope<Relay.ActionAxis.Extracts<GA, LA>, State, Environment> {
        .init(action: .init(preview), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with an embed-only `review` closure.
    public func action<GA, LA>(
        review: @escaping @Sendable (LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Embeds<GA, LA>, State, Environment> {
        .init(action: .init(review), state: state, environment: environment)
    }
}

// MARK: - State axis — static factories (entry)
//
// Like the action entries, the un-set action/env axes are a constructible ``Relay/AxisDefault`` generic: a
// lift/projection chain fills them ``Relay/Identity``, a state-only binding (`presence`/`item`) seals them
// ``Relay/Absurd`` — chosen by the host's expected type.

extension Relay.Scope {
    /// Start a scope from a total state key path.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: WritableKeyPath<GS, LS> & Sendable
    ) -> Relay.Scope<A, Relay.StateAxis.ReadsWrites<GS, LS>, E> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from an optional (affine) state key path → ``Relay/StateAxis/Writes``.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: WritableKeyPath<GS, LS?> & Sendable
    ) -> Relay.Scope<A, Relay.StateAxis.Writes<GS, LS>, E> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from a read-only state getter — serves projection/middleware. Unlabeled so it reads
    /// as a trailing closure: `.state { $0.slice }`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ get: @escaping @Sendable (GS) -> LS
    ) -> Relay.Scope<A, Relay.StateAxis.Reads<GS, LS>, E> {
        .init(action: .init(), state: .init(get), environment: .init())
    }

    /// Start a scope from a **read-only** state key path → ``Relay/StateAxis/Reads`` (a binding /
    /// presentation reads state; a lift, which writes, prefers the writable-key-path `ReadsWrites` entry).
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: KeyPath<GS, LS> & Sendable
    ) -> Relay.Scope<A, Relay.StateAxis.Reads<GS, LS>, E> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from a total state `Lens`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ lens: Lens<GS, LS>
    ) -> Relay.Scope<A, Relay.StateAxis.ReadsWrites<GS, LS>, E> {
        .init(action: .init(), state: .init(lens), environment: .init())
    }

    /// Start a scope from a `(get, set)` closure pair — sugar for `Lens(get:set:)`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        get: @escaping @Sendable (GS) -> LS,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<A, Relay.StateAxis.ReadsWrites<GS, LS>, E> {
        .init(action: .init(), state: .init(Lens(get: get, set: set)), environment: .init())
    }

    /// Start a scope from an **affine** `(preview, set)` closure pair → ``Relay/StateAxis/Writes`` (the
    /// optional-focus case, write-with-skip). Sugar for `AffineTraversal(preview:set:)`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, GS, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (GS) -> LS?,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<A, Relay.StateAxis.Writes<GS, LS>, E> {
        .init(action: .init(), state: .init(AffineTraversal(preview: preview, set: set)), environment: .init())
    }
}

// MARK: - State axis — instance refiners (only where the state axis is still `Identity`)

extension Relay.Scope where State == Relay.Identity {
    /// Replace the pass-through state axis with a read-only getter.
    public func state<GS, LS>(
        _ get: @escaping @Sendable (GS) -> LS
    ) -> Relay.Scope<Action, Relay.StateAxis.Reads<GS, LS>, Environment> {
        .init(action: action, state: .init(get), environment: environment)
    }

    /// Replace the pass-through state axis with a total state key path.
    public func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Replace the pass-through state axis with a total state `Lens`.
    public func state<GS, LS>(
        _ lens: Lens<GS, LS>
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(lens), environment: environment)
    }

    /// Replace the pass-through state axis with an optional (affine) state key path.
    public func state<GS, LS>(
        _ keyPath: WritableKeyPath<GS, LS?> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Writes<GS, LS>, Environment> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Replace the pass-through state axis with a `(get, set)` closure pair.
    public func state<GS, LS>(
        get: @escaping @Sendable (GS) -> LS,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Action, Relay.StateAxis.ReadsWrites<GS, LS>, Environment> {
        .init(action: action, state: .init(Lens(get: get, set: set)), environment: environment)
    }

    /// Replace the pass-through state axis with an affine `(preview, set)` closure pair.
    public func state<GS, LS>(
        preview: @escaping @Sendable (GS) -> LS?,
        set: @escaping @Sendable (GS, LS) -> GS
    ) -> Relay.Scope<Action, Relay.StateAxis.Writes<GS, LS>, Environment> {
        .init(action: action, state: .init(AffineTraversal(preview: preview, set: set)), environment: environment)
    }
}

// MARK: - Environment axis — static factory (entry) + instance refiner

extension Relay.Scope {
    /// Start a scope from the environment axis (action/state pass-through `Identity`).
    public static func environment<GE, LE>(
        _ narrow: @escaping @Sendable (GE) -> LE
    ) -> Relay.Scope<Relay.Identity, Relay.Identity, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: .init(), state: .init(), environment: .init(narrow))
    }
}

extension Relay.Scope where Environment == Relay.Identity {
    /// Replace the pass-through environment axis with a narrowing closure.
    public func environment<GE, LE>(
        _ narrow: @escaping @Sendable (GE) -> LE
    ) -> Relay.Scope<Action, State, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: action, state: state, environment: .init(narrow))
    }

    /// Replace the pass-through environment axis with a narrowing key path.
    public func environment<GE, LE>(
        _ keyPath: KeyPath<GE, LE> & Sendable
    ) -> Relay.Scope<Action, State, Relay.EnvironmentAxis.Narrows<GE, LE>> {
        .init(action: action, state: state, environment: .init(keyPath))
    }
}
