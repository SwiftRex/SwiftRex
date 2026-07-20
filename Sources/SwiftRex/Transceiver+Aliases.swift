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
