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

// A `Behavior` reduces, produces effects, and supervises over its `(Action, State, Environment)` — a `Rig`.
extension Behavior: Rig {}

// A `Reducer` folds actions into state over its `(Action, State)` — a `Transceiver`.
extension Reducer: Transceiver {
    public typealias Action = ActionType
    public typealias State = StateType
}
