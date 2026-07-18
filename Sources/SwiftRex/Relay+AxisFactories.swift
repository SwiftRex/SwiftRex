// SPDX-License-Identifier: Apache-2.0

import CoreFP

// MARK: - Single-axis witness factories (`.state(…)` / `.action(…)` on the concrete witnesses)
//
// These are the axis-*separated* counterpart of the chained ``Relay/Scope`` builder. A host that takes a
// value on ONE axis — a two-way `binding` (reads state, embeds action) or a `.on` bridge (extracts a
// trigger, embeds an emit) — types each parameter as the concrete capability witness it needs. Because
// the factories are statics on the concrete witness (not the protocol), leading-dot resolves them AND
// autocomplete in each slot offers only that axis' spellings: a `Reads` slot shows `.state(…)`, an
// `Embeds` slot shows `.action(…)`, and neither offers the other. The full strategy zoo is preserved —
// key path, closure, optic — each returning the minimal witness the slot needs.

extension Relay.StateAxis.Reads {
    /// Read the state slice through a key path.
    public static func state(_ keyPath: KeyPath<G, L> & Sendable) -> Relay.StateAxis.Reads<G, L> { .init(keyPath) }
    /// Read the state slice through a getter closure.
    public static func state(_ get: @escaping @Sendable (G) -> L) -> Relay.StateAxis.Reads<G, L> { .init(get) }
    /// Read the state slice through a `Lens` (only its `get` is used).
    public static func state(_ lens: Lens<G, L>) -> Relay.StateAxis.Reads<G, L> { .init(lens) }
}

extension Relay.ActionAxis.Embeds {
    /// Embed the value into an action through a `\.case` key path.
    public static func action(_ keyPath: PrismKeyPath<G, L>) -> Relay.ActionAxis.Embeds<G, L> { .init(keyPath) }
    /// Embed the value into an action through a `Prism` (only its `review` is used).
    public static func action(_ prism: CoreFP.Prism<G, L>) -> Relay.ActionAxis.Embeds<G, L> { .init(prism) }
    /// Embed the value into an action through a `review` closure.
    public static func action(review: @escaping @Sendable (L) -> G) -> Relay.ActionAxis.Embeds<G, L> { .init(review) }
}

extension Relay.ActionAxis.Extracts {
    /// Extract the trigger from an action through a `\.case` key path.
    public static func action(_ keyPath: PrismKeyPath<G, L>) -> Relay.ActionAxis.Extracts<G, L> { .init(keyPath) }
    /// Extract the trigger from an action through a `Prism` (only its `preview` is used).
    public static func action(_ prism: CoreFP.Prism<G, L>) -> Relay.ActionAxis.Extracts<G, L> { .init(prism) }
    /// Extract the trigger from an action through a `preview` closure (`nil` ⇒ not a match).
    public static func action(preview: @escaping @Sendable (G) -> L?) -> Relay.ActionAxis.Extracts<G, L> { .init(preview) }
}
