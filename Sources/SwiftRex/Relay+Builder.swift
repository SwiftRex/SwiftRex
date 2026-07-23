// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The fluent builder for `Relay.Scope`. Every step returns a `Relay.Scope` (no partial builder type):
//   - a **static factory** starts a scope by setting one axis to a real ``Relay/…Axis/LiftingProtocol``
//     witness; the other two stay un-set as a constructible ``Relay/AxisDefault`` generic. Static entries
//     exist ONLY for real witnesses — you never construct an `Identity` or `Absurd` via a factory.
//   - an **instance refiner** replaces one axis while keeping the others; it is gated
//     `where ThatStrategy == Relay.Identity<ThatGlobal>`, so you may specialise an axis exactly once.
//     `.action().state()` works; `.state().state()` does not (state is no longer `Identity`), and a sealed
//     ``Relay/Absurd`` axis offers no refiner at all — enforced by conformance, no `@available`.
//
// Every signature takes its optics rooted at **`Self`'s global parameters** (`Action`/`State`/
// `Environment`), so the roots of `\.case` / `\.slice` key paths are pinned by whatever fixes `Self` — a
// host call for inline chains, or the concrete ``ScopeOf`` entry type for declared ones:
//
//     store.projection(.action(prism).state(\.slice))                    // host pins the globals
//     static let child = ScopeOf<AppFeature>                             // the entry type pins the globals
//         .action(\.child).state(\.child).environment(\.childEnv)
//
// A declared chain may leave axes un-set — the entry statics carry them through as concrete
// ``Relay/Identity``, so a partial declaration is a complete type the env-ignoring hosts accept:
//
//     static let pair = ScopeOf<AppFeature>.action(\.child).state(\.child)

extension Relay.Scope {
    /// The identity re-index — the all-``Relay/Identity`` scope (`Global → Global` on every axis), the
    /// bare-declaration entry point for the builder. Typed explicitly (NOT `Self`) so it can lead an
    /// implicit-member chain: the chain's base is the FINAL type, whose strategies are the refined
    /// witnesses — a `Self`-typed entry could never match it.
    public static var identity: Relay.Scope<
        Action, Relay.Identity<Action>, State, Relay.Identity<State>, Environment, Relay.Identity<Environment>
    > {
        .init(action: .init(), state: .init(), environment: .init())
    }
}

// MARK: - Declared-scope entry statics (only on the all-`Identity` specialization — i.e. `ScopeOf<R>`)
//
// `ScopeOf<R>` is a fully CONCRETE type, so these statics start a declared chain with no annotation at
// all: `ScopeOf<AppFeature>.action(\.child).state(\.child).environment(…)`. They are the instance
// refiners minus the instance — un-set axes carry through as `Self`'s own (concretely `Identity`) types,
// so even a partial chain (`.action(…).state(…)`) is a complete, host-ready type. The host-driven
// factories above stay reserved for inline chains, where the host's expected type fills the un-set axes.

extension Relay.Scope where
    ActionStrategy == Relay.Identity<Action>,
    StateStrategy == Relay.Identity<State>,
    EnvironmentStrategy == Relay.Identity<Environment> {
    /// Start a declared scope from the action axis via a `Prism` (duplex — serves every host).
    public static func action<LA>(
        _ prism: CoreFP.Prism<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(prism), state: .init(), environment: .init())
    }

    /// Start a declared scope from the action axis via a `\.case` key path.
    public static func action<LA>(
        _ keyPath: PrismKeyPath<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(keyPath), state: .init(), environment: .init())
    }

    /// Start a declared scope from a `(preview, review)` closure pair — sugar for `Prism(preview:review:)`.
    public static func action<LA>(
        preview: @escaping @Sendable (Action) -> LA?,
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(Prism(preview: preview, review: review)), state: .init(), environment: .init())
    }

    /// Start a declared scope from an extract-only `preview` closure → ``Relay/ActionAxis/Extracts``.
    public static func action<LA>(
        preview: @escaping @Sendable (Action) -> LA?
    ) -> Relay.Scope<Action, Relay.ActionAxis.Extracts<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(preview), state: .init(), environment: .init())
    }

    /// Start a declared scope from an embed-only `review` closure → ``Relay/ActionAxis/Embeds``.
    public static func action<LA>(
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Embeds<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(review), state: .init(), environment: .init())
    }

    /// Start a declared scope from a total state key path.
    public static func state<LS>(
        _ keyPath: WritableKeyPath<State, LS> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a declared scope from an optional (affine) state key path → ``Relay/StateAxis/Writes``.
    public static func state<LS>(
        _ keyPath: WritableKeyPath<State, LS?> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Writes<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a declared scope from a read-only state getter (`.state { $0.slice }`).
    public static func state<LS>(
        _ get: @escaping @Sendable (State) -> LS
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Reads<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(get), environment: .init())
    }

    /// Start a declared scope from a **read-only** state key path → ``Relay/StateAxis/Reads``.
    public static func state<LS>(
        _ keyPath: KeyPath<State, LS> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Reads<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a declared scope from a total state `Lens`.
    public static func state<LS>(
        _ lens: Lens<State, LS>
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(lens), environment: .init())
    }

    /// Start a declared scope from a `(get, set)` closure pair — sugar for `Lens(get:set:)`.
    public static func state<LS>(
        get: @escaping @Sendable (State) -> LS,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(Lens(get: get, set: set)), environment: .init())
    }

    /// Start a declared scope from an **affine** `(preview, set)` closure pair → ``Relay/StateAxis/Writes``.
    public static func state<LS>(
        preview: @escaping @Sendable (State) -> LS?,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Writes<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: .init(), state: .init(AffineTraversal(preview: preview, set: set)), environment: .init())
    }

    /// Start a declared scope from a narrowing environment closure.
    public static func environment<LE>(
        _ narrow: @escaping @Sendable (Environment) -> LE
    ) -> Relay.Scope<Action, ActionStrategy, State, StateStrategy, Environment, Relay.EnvironmentAxis.Narrows<Environment, LE>> {
        .init(action: .init(), state: .init(), environment: .init(narrow))
    }

    /// Start a declared scope from a narrowing environment key path.
    public static func environment<LE>(
        _ keyPath: KeyPath<Environment, LE> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, StateStrategy, Environment, Relay.EnvironmentAxis.Narrows<Environment, LE>> {
        .init(action: .init(), state: .init(), environment: .init(keyPath))
    }
}

// MARK: - Action axis — static factories (entry)
//
// The un-set state/env axes are a constructible generic (``Relay/AxisDefault``) over the SAME globals as
// `Self`: a lift chain fills them ``Relay/Identity``, an action-only `.on` seals them ``Relay/Absurd`` —
// the choice is made by the host's expected type, one entry serving both.

extension Relay.Scope {
    /// Start a scope from the action axis via a `Prism` (duplex — serves every host).
    public static func action<LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ prism: CoreFP.Prism<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, S, Environment, E>
    where S.Global == State, E.Global == Environment {
        .init(action: .init(prism), state: .init(), environment: .init())
    }

    /// Start a scope from the action axis via a `\.case` key path.
    public static func action<LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: PrismKeyPath<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, S, Environment, E>
    where S.Global == State, E.Global == Environment {
        .init(action: .init(keyPath), state: .init(), environment: .init())
    }

    /// Start a scope from a `(preview, review)` closure pair — sugar for `Prism(preview:review:)`.
    public static func action<LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (Action) -> LA?,
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, S, Environment, E>
    where S.Global == State, E.Global == Environment {
        .init(action: .init(Prism(preview: preview, review: review)), state: .init(), environment: .init())
    }

    /// Start a scope from an extract-only `preview` closure → ``Relay/ActionAxis/Extracts`` (a
    /// reducer/behavior can extract; a projection, which needs to embed, won't accept it).
    public static func action<LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (Action) -> LA?
    ) -> Relay.Scope<Action, Relay.ActionAxis.Extracts<Action, LA>, State, S, Environment, E>
    where S.Global == State, E.Global == Environment {
        .init(action: .init(preview), state: .init(), environment: .init())
    }

    /// Start a scope from an embed-only `review` closure → ``Relay/ActionAxis/Embeds`` (a projection
    /// dispatches; a reducer/behavior, which needs to extract, won't accept it).
    public static func action<LA, S: Relay.StateAxis.Strategy & Relay.AxisDefault, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Embeds<Action, LA>, State, S, Environment, E>
    where S.Global == State, E.Global == Environment {
        .init(action: .init(review), state: .init(), environment: .init())
    }
}

// MARK: - Action axis — instance refiners (only where the action axis is still `Identity`)

extension Relay.Scope where ActionStrategy == Relay.Identity<Action> {
    /// Replace the pass-through action axis via a `Prism`, keeping state and environment.
    public func action<LA>(
        _ prism: CoreFP.Prism<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(prism), state: state, environment: environment)
    }

    /// Replace the pass-through action axis via a `\.case` key path.
    public func action<LA>(
        _ keyPath: PrismKeyPath<Action, LA>
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(keyPath), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with a `(preview, review)` closure pair.
    public func action<LA>(
        preview: @escaping @Sendable (Action) -> LA?,
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Prism<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(Prism(preview: preview, review: review)), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with an extract-only `preview` closure.
    public func action<LA>(
        preview: @escaping @Sendable (Action) -> LA?
    ) -> Relay.Scope<Action, Relay.ActionAxis.Extracts<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(preview), state: state, environment: environment)
    }

    /// Replace the pass-through action axis with an embed-only `review` closure.
    public func action<LA>(
        review: @escaping @Sendable (LA) -> Action
    ) -> Relay.Scope<Action, Relay.ActionAxis.Embeds<Action, LA>, State, StateStrategy, Environment, EnvironmentStrategy> {
        .init(action: .init(review), state: state, environment: environment)
    }
}

// MARK: - State axis — static factories (entry)
//
// Like the action entries, the un-set action/env axes are a constructible ``Relay/AxisDefault`` generic
// over `Self`'s globals: a lift/projection chain fills them ``Relay/Identity``, a state-only binding
// (`presence`/`item`) seals them ``Relay/Absurd`` — chosen by the host's expected type.

extension Relay.Scope {
    /// Start a scope from a total state key path.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: WritableKeyPath<State, LS> & Sendable
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from an optional (affine) state key path → ``Relay/StateAxis/Writes``.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: WritableKeyPath<State, LS?> & Sendable
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.Writes<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from a read-only state getter — serves projection/middleware. Unlabeled so it reads
    /// as a trailing closure: `.state { $0.slice }`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ get: @escaping @Sendable (State) -> LS
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.Reads<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(get), environment: .init())
    }

    /// Start a scope from a **read-only** state key path → ``Relay/StateAxis/Reads`` (a binding /
    /// presentation reads state; a lift, which writes, prefers the writable-key-path `ReadsWrites` entry).
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ keyPath: KeyPath<State, LS> & Sendable
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.Reads<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(keyPath), environment: .init())
    }

    /// Start a scope from a total state `Lens`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        _ lens: Lens<State, LS>
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(lens), environment: .init())
    }

    /// Start a scope from a `(get, set)` closure pair — sugar for `Lens(get:set:)`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        get: @escaping @Sendable (State) -> LS,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(Lens(get: get, set: set)), environment: .init())
    }

    /// Start a scope from an **affine** `(preview, set)` closure pair → ``Relay/StateAxis/Writes`` (the
    /// optional-focus case, write-with-skip). Sugar for `AffineTraversal(preview:set:)`.
    public static func state<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, LS, E: Relay.EnvironmentAxis.Strategy & Relay.AxisDefault>(
        preview: @escaping @Sendable (State) -> LS?,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, A, State, Relay.StateAxis.Writes<State, LS>, Environment, E>
    where A.Global == Action, E.Global == Environment {
        .init(action: .init(), state: .init(AffineTraversal(preview: preview, set: set)), environment: .init())
    }
}

// MARK: - State axis — instance refiners (only where the state axis is still `Identity`)

extension Relay.Scope where StateStrategy == Relay.Identity<State> {
    /// Replace the pass-through state axis with a read-only getter.
    public func state<LS>(
        _ get: @escaping @Sendable (State) -> LS
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Reads<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(get), environment: environment)
    }

    /// Replace the pass-through state axis with a total state key path.
    public func state<LS>(
        _ keyPath: WritableKeyPath<State, LS> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Replace the pass-through state axis with a total state `Lens`.
    public func state<LS>(
        _ lens: Lens<State, LS>
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(lens), environment: environment)
    }

    /// Replace the pass-through state axis with an optional (affine) state key path.
    public func state<LS>(
        _ keyPath: WritableKeyPath<State, LS?> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Writes<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(keyPath), environment: environment)
    }

    /// Replace the pass-through state axis with a `(get, set)` closure pair.
    public func state<LS>(
        get: @escaping @Sendable (State) -> LS,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.ReadsWrites<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(Lens(get: get, set: set)), environment: environment)
    }

    /// Replace the pass-through state axis with an affine `(preview, set)` closure pair.
    public func state<LS>(
        preview: @escaping @Sendable (State) -> LS?,
        set: @escaping @Sendable (State, LS) -> State
    ) -> Relay.Scope<Action, ActionStrategy, State, Relay.StateAxis.Writes<State, LS>, Environment, EnvironmentStrategy> {
        .init(action: action, state: .init(AffineTraversal(preview: preview, set: set)), environment: environment)
    }
}

// MARK: - Environment axis — static factory (entry) + instance refiner

extension Relay.Scope {
    /// Start a scope from the environment axis (action/state stay un-set — the host's expected type
    /// fills them `Identity` or `Absurd`).
    public static func environment<A: Relay.ActionAxis.Strategy & Relay.AxisDefault, S: Relay.StateAxis.Strategy & Relay.AxisDefault, LE>(
        _ narrow: @escaping @Sendable (Environment) -> LE
    ) -> Relay.Scope<Action, A, State, S, Environment, Relay.EnvironmentAxis.Narrows<Environment, LE>>
    where A.Global == Action, S.Global == State {
        .init(action: .init(), state: .init(), environment: .init(narrow))
    }
}

extension Relay.Scope where EnvironmentStrategy == Relay.Identity<Environment> {
    /// Replace the pass-through environment axis with a narrowing closure.
    public func environment<LE>(
        _ narrow: @escaping @Sendable (Environment) -> LE
    ) -> Relay.Scope<Action, ActionStrategy, State, StateStrategy, Environment, Relay.EnvironmentAxis.Narrows<Environment, LE>> {
        .init(action: action, state: state, environment: .init(narrow))
    }

    /// Replace the pass-through environment axis with a narrowing key path.
    public func environment<LE>(
        _ keyPath: KeyPath<Environment, LE> & Sendable
    ) -> Relay.Scope<Action, ActionStrategy, State, StateStrategy, Environment, Relay.EnvironmentAxis.Narrows<Environment, LE>> {
        .init(action: action, state: state, environment: .init(keyPath))
    }
}
