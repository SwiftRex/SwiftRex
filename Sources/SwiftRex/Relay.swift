// SPDX-License-Identifier: Apache-2.0

import CoreFP

/// The re-indexing of one ``Transceiver`` into another — declared once, applied to any store whose
/// `(Action, State)` matches the global domain. It carries the two opposite lanes:
/// - **`action`** merges a local action up into the global one (`Local.Action → Global.Action`);
/// - **`state`** projects the global state down to the local one (`Global.State → Local.State`).
///
/// Category theory: a `Relay` **is `dimap`** — the store profunctor's own reindexing. `dimap :
/// (a′→a) → (b→b′) → P a b → P a′ b′` instantiated at `P(Global.Action, Global.State) →
/// P(Local.Action, Local.State)` demands exactly `(action, state)`. `Relay`s compose (``then(_:)``),
/// so they form a category. Apply one with ``StoreType/projection(_:)`` to get a ``StoreProjection``.
///
/// This is the env-free (simplex) link — one movement per lane. The store projection, `ViewStore`
/// mapping, SwiftUI bindings, and presentation all reduce to it. The env-aware, full-duplex counterpart
/// (the feature *lift*) is `Gateway`.
public struct Relay<Global: Transceiver, Local: Transceiver>: Sendable {
    /// Merge a local action up into the global action type.
    public let action: @Sendable (Local.Action) -> Global.Action
    /// Project the global state down to the local state type.
    public let state: @MainActor @Sendable (Global.State) -> Local.State

    public init(
        action: @escaping @Sendable (Local.Action) -> Global.Action,
        state: @escaping @MainActor @Sendable (Global.State) -> Local.State
    ) {
        self.action = action
        self.state = state
    }
}

extension Relay {
    /// Pure-optic spelling — a ``Prism`` on the action (its `review` is the `action` lane) and a
    /// ``Lens`` on the state (its `get` is the `state` lane). The most general optic form; the key-path
    /// and prism-key-path overloads below funnel into it.
    public init(
        action: Prism<Global.Action, Local.Action>,
        state: Lens<Global.State, Local.State>
    ) {
        self.init(action: action.review, state: state.get)
    }
}

extension Relay where Global.Action: Prismatic {
    /// Key-path spelling — a `\.case` action prism key path (its `review` is the `action` lane) and a
    /// state key path (its read is the `state` lane). Compile-proof: the wiring only type-checks if the
    /// case and slot line up with the local domain.
    public init(
        action: PrismKeyPath<Global.Action, Local.Action>,
        state: KeyPath<Global.State, Local.State> & Sendable
    ) {
        self.init(action: Prism(action).review, state: { $0[keyPath: state] })
    }
}

extension Relay {
    /// Compose two relays — `dimap` composition (`Global ↞ Local ↞ Inner`).
    public func then<Inner: Transceiver>(_ inner: Relay<Local, Inner>) -> Relay<Global, Inner> {
        Relay<Global, Inner>(
            action: { self.action(inner.action($0)) },
            state: { inner.state(self.state($0)) }
        )
    }
}

extension StoreType {
    /// Project this store through a ``Relay`` — apply the `dimap` to view it as a narrower store.
    /// The relay's global domain must match this store's `(Action, State)`.
    @MainActor
    public func projection<Global: Transceiver, Local: Transceiver>(
        _ relay: Relay<Global, Local>
    ) -> StoreProjection<Local.Action, Local.State> where Global.Action == Action, Global.State == State {
        projection(action: relay.action, state: relay.state)
    }
}
