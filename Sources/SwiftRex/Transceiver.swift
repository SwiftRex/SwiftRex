// SPDX-License-Identifier: Apache-2.0

/// The `(Action, State)` two-way channel — the pure, type-level interface of a feature or a store, with
/// `Action` flowing **in** (uplink) and `State` flowing **out** (downlink). ``Rig`` refines it with an
/// `Environment`; a ``Store`` / ``StoreProjection`` realizes it at runtime as a ``StoreType``; a ``Relay``
/// re-indexes one `Transceiver` into another.
///
/// Category theory: a `Transceiver` is a **profunctor** `Action ⇸ State` — contravariant in `Action`,
/// covariant in `State` — concretely a Moore/Mealy **transducer**.
public protocol Transceiver<Action, State> {
    /// The action type — transmitted **in** (uplink).
    associatedtype Action: Sendable
    /// The state type — received **out** (downlink).
    associatedtype State: Sendable
}

/// A ``Transceiver`` that also reaches the world — the `(Action, State, Environment)` triad. `Environment`
/// is the antenna / backhaul: the feature's live line to effects and dependencies.
///
/// Category theory: the ``Transceiver`` profunctor in the Kleisli category of the effect monad, with a
/// `Reader` carrying the `Environment`.
public protocol Rig<Action, State, Environment>: Transceiver {
    /// The environment (dependencies) type — the line to the world.
    associatedtype Environment: Sendable
}

// Conformances live with their types: `StoreType: Transceiver` (StoreType.swift), `Behavior: Rig`
// (Behavior.swift), `Reducer: Transceiver` (Reducer.swift).
