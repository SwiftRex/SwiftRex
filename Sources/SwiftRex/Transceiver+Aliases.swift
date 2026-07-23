// SPDX-License-Identifier: Apache-2.0

// Single-generic aliases over a ``Transceiver`` / ``Rig`` triad — pass one feature/global type instead of
// repeating `<Action, State, Environment>`. Works for any conformer: an app-global `Rig` (e.g. `AppFeature`)
// or a feature `Rig`. `Reducer`/`StoreType` need only the `(Action, State)` pair, so they take a
// ``Transceiver``; `Behavior`/`Middleware`/`Store` reach the world, so they take a ``Rig``.

/// A ``Behavior`` over a ``Rig``'s triad — `BehaviorOf<AppFeature>` == `Behavior<AppAction, AppState, World>`.
public typealias BehaviorOf<R: Rig> = Behavior<R.Action, R.State, R.Environment>

/// A ``Middleware`` over a ``Rig``'s triad.
public typealias MiddlewareOf<R: Rig> = Middleware<R.Action, R.State, R.Environment>

/// A concrete ``Store`` over a ``Rig``'s triad.
public typealias StoreOf<R: Rig> = Store<R.Action, R.State, R.Environment>

/// A ``Reducer`` over a ``Transceiver``'s `(Action, State)` — no environment.
public typealias ReducerOf<R: Transceiver> = Reducer<R.Action, R.State>

/// The existential ``StoreType`` over a ``Transceiver``'s `(Action, State)`.
public typealias StoreTypeOf<R: Transceiver> = any StoreType<R.Action, R.State>

/// The **identity** ``Relay/Scope`` over a ``Rig``'s triad — all three global slots pinned to the Rig,
/// all three strategies pass-through ``Relay/Identity``. A fully concrete type, so it is the *entry* for
/// declared scopes: its static factories (gated on the all-`Identity` shape) start the builder chain with
/// every key-path root already pinned, and each step re-types the scope as an axis specialises:
///
/// ```swift
/// static let child = ScopeOf<AppFeature>.action(\.child).state(\.child).environment(\.childEnv)
/// ```
///
/// Un-set axes stay concretely `Identity`, so a partial chain (`.action(…).state(…)`) is still a complete
/// type — accepted by the env-ignoring hosts' generic-environment overloads. Note the *result* of a chain
/// is not a `ScopeOf` (its strategies are the refined witnesses), which is why this alias appears on the
/// expression side, never as the annotation of a refined scope.
public typealias ScopeOf<R: Rig> = Relay.Scope<
    R.Action, Relay.Identity<R.Action>,
    R.State, Relay.Identity<R.State>,
    R.Environment, Relay.Identity<R.Environment>
>
