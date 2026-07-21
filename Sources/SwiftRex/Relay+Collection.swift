// SPDX-License-Identifier: Apache-2.0

import CoreFP

// MARK: - Collection capabilities (decorator families, consumed ONLY by liftCollection / liftEach)
//
// These do NOT touch the base action/state families. `Behavior.lift` keeps offering only
// `Extracts`/`Embeds`/`Prism` and `Reads`/`Writes`/`ReadsWrites`, so its completion stays clean and its
// semantics are unchanged. The id-transport context a collection needs (which element an action addresses,
// how to re-stamp an element's emitted effects/channels) rides in these decorator witnesses, and only the
// `liftCollection`/`liftEach` hosts constrain on them — the compiler enforces that boundary.

extension Relay.ActionAxis {
    /// Route-to-one action lane for ``Behavior/liftCollection(_:)`` — extracts the addressed element's
    /// `id` **and** its local action inbound, and re-embeds an emitted local action addressed at an `id`.
    /// A decorator over a base `Prism<G, ElementAction<ID, L>>` — the id context the single lift lacks.
    public protocol ElementProtocol: LiftingProtocol {
        associatedtype ID: Hashable & Sendable
        var preview: @Sendable (G) -> (id: ID, action: L)? { get }
        var review: @Sendable (ID, L) -> G { get }
    }

    /// Broadcast action lane for ``Behavior/liftEach(_:)`` — no id inbound (every present element receives
    /// the action), re-embeds each element's emitted action addressed at its own `id`.
    public protocol BroadcastProtocol: LiftingProtocol {
        associatedtype ID: Hashable & Sendable
        var preview: @Sendable (G) -> L? { get }
        var review: @Sendable (ID, L) -> G { get }
    }

    /// Route-to-one witness. Reuses a base ``Prism`` over ``ElementAction`` internally.
    public struct Element<G: Sendable, ID: Hashable & Sendable, L: Sendable>: ElementProtocol {
        public let preview: @Sendable (G) -> (id: ID, action: L)?
        public let review: @Sendable (ID, L) -> G
        public init(
            preview: @escaping @Sendable (G) -> (id: ID, action: L)?,
            review: @escaping @Sendable (ID, L) -> G
        ) {
            self.preview = preview
            self.review = review
        }
        public init(_ prism: CoreFP.Prism<G, ElementAction<ID, L>>) {
            preview = { prism.preview($0).map { (id: $0.id, action: $0.action) } }
            review = { id, action in prism.review(ElementAction(id, action: action)) }
        }
        public init(_ keyPath: PrismKeyPath<G, ElementAction<ID, L>>) { self.init(CoreFP.Prism(keyPath)) }
    }

    /// Broadcast witness. Plain `preview` inbound + an id-addressed `review` outbound.
    public struct Broadcast<G: Sendable, ID: Hashable & Sendable, L: Sendable>: BroadcastProtocol {
        public let preview: @Sendable (G) -> L?
        public let review: @Sendable (ID, L) -> G
        public init(
            preview: @escaping @Sendable (G) -> L?,
            review: @escaping @Sendable (ID, L) -> G
        ) {
            self.preview = preview
            self.review = review
        }
        /// Extract from a plain inbound ``Prism``, re-address element outputs into an ``ElementAction`` prism.
        public init(inbound: CoreFP.Prism<G, L>, into element: CoreFP.Prism<G, ElementAction<ID, L>>) {
            preview = inbound.preview
            review = { id, action in element.review(ElementAction(id, action: action)) }
        }
    }
}

extension Relay.StateAxis {
    /// Keyed-container state lane for the collection hosts — a `Lens` to the container, a per-`id`
    /// `AffineTraversal` into an element (the **unwrapped** focus), and an enumerator of present ids for
    /// the supervise fan-out. For a fixed id it reconstructs a base ``Writes``.
    public protocol KeyedProtocol: LiftingProtocol {
        associatedtype ID: Hashable & Sendable
        associatedtype Container: Sendable
        var container: Lens<G, Container> { get }
        var element: @Sendable (ID) -> AffineTraversal<Container, L> { get }
        var ids: @Sendable (Container) -> [ID] { get }
    }

    /// Keyed witness — general form (any container + explicit element/ids optics).
    public struct Keyed<G: Sendable, Container: Sendable, ID: Hashable & Sendable, L: Sendable>: KeyedProtocol {
        public let container: Lens<G, Container>
        public let element: @Sendable (ID) -> AffineTraversal<Container, L>
        public let ids: @Sendable (Container) -> [ID]
        public init(
            container: Lens<G, Container>,
            element: @escaping @Sendable (ID) -> AffineTraversal<Container, L>,
            ids: @escaping @Sendable (Container) -> [ID]
        ) {
            self.container = container
            self.element = element
            self.ids = ids
        }
    }
}

// MARK: - Keyed witness conveniences (one per locator strategy)

extension Relay.StateAxis.Keyed
where Container: MutableCollection & Sendable, Container.Element == L, L: Identifiable, ID == L.ID, Container.Index: Sendable {
    /// Keyed over a mutable collection of `Identifiable` elements, located by `id`.
    public init(collection: Lens<G, Container>) {
        self.init(container: collection, element: { Container.ix(id: $0) }, ids: { $0.map(\.id) })
    }
}

extension Relay.StateAxis.Keyed
where Container: MutableCollection & Sendable, Container.Element == L, Container.Index: Sendable {
    /// Keyed over a mutable collection, located by a custom `Hashable` key path (element need not be `Identifiable`).
    public init(collection: Lens<G, Container>, id identifier: KeyPath<L, ID> & Sendable) {
        self.init(
            container: collection,
            element: { Container.ix(id: $0, by: identifier) },
            ids: { c in c.map { $0[keyPath: identifier] } }
        )
    }
}

extension Relay.StateAxis.Keyed
where Container: MutableCollection & Sendable, Container.Element == L, ID == Container.Index, Container.Index: Hashable & Sendable {
    /// Keyed over a mutable collection by **position** (`Container.Index`).
    public init(indexed collection: Lens<G, Container>) {
        self.init(container: collection, element: { Container.ix($0) }, ids: { Array($0.indices) })
    }
}

extension Relay.StateAxis.Keyed where Container == [ID: L] {
    /// Keyed over a dictionary, located by `Key`.
    public init(dictionary: Lens<G, [ID: L]>) {
        self.init(container: dictionary, element: { [ID: L].ix(key: $0) }, ids: { Array($0.keys) })
    }
}

// MARK: - Broadcast helper: a Traversal over every present element (shared by the liftEach hosts)

extension Relay.StateAxis.KeyedProtocol {
    /// A `Traversal` visiting every present element — the broadcast (`liftEach`) view of a keyed lane.
    var eachTraversal: Traversal<Container, L> {
        Traversal(
            getAll: { container in ids(container).compactMap { element($0).preview(container) } },
            modifyMut: { container, transform in
                for id in ids(container) { element(id).tryModifyMut(&container, transform) }
            }
        )
    }
}

// MARK: - Builder entries (host-driven — the SAME leading-dot chain as a single child)
//
// Route-one action entries resolve to `Element` by SPECIFICITY (the prism targets an `ElementAction`), so
// they need no label. `liftCollection`/`liftEach` is the only signal; the host's expected type also
// disambiguates against the base entries (e.g. `.state(\.identifiableArray)` → `ReadsWrites` for a
// projection, `Keyed` for `liftCollection`). Broadcast (no id inbound) and the non-`Identifiable` state
// locators can't key on specificity, so they carry the minimum extra param/label.

// MARK: Action — route-to-one (Element)

extension Relay.Scope {
    /// Start a route-to-one scope from a prism into an ``ElementAction`` case.
    public static func action<GA, ID: Hashable & Sendable, LA>(
        _ prism: CoreFP.Prism<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, Relay.Identity, Relay.Identity> {
        .init(action: .init(prism), state: .init(), environment: .init())
    }

    /// Start a route-to-one scope from a `\.case` key path into an ``ElementAction``.
    public static func action<GA, ID: Hashable & Sendable, LA>(
        _ keyPath: PrismKeyPath<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, Relay.Identity, Relay.Identity> {
        .init(action: .init(keyPath), state: .init(), environment: .init())
    }

    /// Start a route-to-one scope from a `(preview, review)` closure pair (macro-free).
    public static func action<GA, ID: Hashable & Sendable, LA>(
        preview: @escaping @Sendable (GA) -> (id: ID, action: LA)?,
        review: @escaping @Sendable (ID, LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, Relay.Identity, Relay.Identity> {
        .init(action: .init(preview: preview, review: review), state: .init(), environment: .init())
    }

    /// Replace the action axis with a route-to-one ``ElementAction`` prism.
    public func action<GA, ID: Hashable & Sendable, LA>(
        _ prism: CoreFP.Prism<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, State, Environment> {
        .init(action: .init(prism), state: state, environment: environment)
    }

    /// Replace the action axis with a route-to-one ``ElementAction`` key path.
    public func action<GA, ID: Hashable & Sendable, LA>(
        _ keyPath: PrismKeyPath<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, State, Environment> {
        .init(action: .init(keyPath), state: state, environment: environment)
    }

    /// Replace the action axis with a route-to-one `(preview, review)` closure pair.
    public func action<GA, ID: Hashable & Sendable, LA>(
        preview: @escaping @Sendable (GA) -> (id: ID, action: LA)?,
        review: @escaping @Sendable (ID, LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Element<GA, ID, LA>, State, Environment> {
        .init(action: .init(preview: preview, review: review), state: state, environment: environment)
    }
}

// MARK: Action — broadcast (Broadcast) — always labelled (no id inbound to key on)

extension Relay.Scope {
    /// Start a broadcast scope: extract from a plain inbound prism, re-address outputs into an
    /// ``ElementAction`` prism.
    public static func action<GA, ID: Hashable & Sendable, LA>(
        broadcast inbound: CoreFP.Prism<GA, LA>,
        into element: CoreFP.Prism<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Broadcast<GA, ID, LA>, Relay.Identity, Relay.Identity> {
        .init(action: .init(inbound: inbound, into: element), state: .init(), environment: .init())
    }

    /// Start a broadcast scope from a raw inbound `preview` + id-addressed `embed`.
    public static func action<GA, ID: Hashable & Sendable, LA>(
        broadcast preview: @escaping @Sendable (GA) -> LA?,
        embed: @escaping @Sendable (ID, LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Broadcast<GA, ID, LA>, Relay.Identity, Relay.Identity> {
        .init(action: .init(preview: preview, review: embed), state: .init(), environment: .init())
    }

    /// Replace the action axis with a broadcast (`inbound` prism → `into` ``ElementAction`` prism).
    public func action<GA, ID: Hashable & Sendable, LA>(
        broadcast inbound: CoreFP.Prism<GA, LA>,
        into element: CoreFP.Prism<GA, ElementAction<ID, LA>>
    ) -> Relay.Scope<Relay.ActionAxis.Broadcast<GA, ID, LA>, State, Environment> {
        .init(action: .init(inbound: inbound, into: element), state: state, environment: environment)
    }

    /// Replace the action axis with a broadcast raw `preview` + id-addressed `embed`.
    public func action<GA, ID: Hashable & Sendable, LA>(
        broadcast preview: @escaping @Sendable (GA) -> LA?,
        embed: @escaping @Sendable (ID, LA) -> GA
    ) -> Relay.Scope<Relay.ActionAxis.Broadcast<GA, ID, LA>, State, Environment> {
        .init(action: .init(preview: preview, review: embed), state: state, environment: environment)
    }
}

// MARK: State — keyed (Keyed) — refiners, one per locator × container spelling

extension Relay.Scope {
    /// Refine the state axis to a keyed collection of `Identifiable` elements (`WritableKeyPath`).
    public func state<GS, C: MutableCollection & Sendable, LS>(
        _ keyPath: WritableKeyPath<GS, C> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, LS.ID, LS>, Environment>
    where C.Element == LS, LS: Identifiable, LS.ID: Hashable & Sendable, C.Index: Sendable {
        .init(action: action, state: .init(collection: lens(keyPath)), environment: environment)
    }

    /// Refine the state axis to a keyed collection of `Identifiable` elements (`Lens`).
    public func state<GS, C: MutableCollection & Sendable, LS>(
        _ container: Lens<GS, C>
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, LS.ID, LS>, Environment>
    where C.Element == LS, LS: Identifiable, LS.ID: Hashable & Sendable, C.Index: Sendable {
        .init(action: action, state: .init(collection: container), environment: environment)
    }

    /// Refine the state axis to a keyed collection located by a custom `Hashable` key path (`WritableKeyPath`).
    public func state<GS, C: MutableCollection & Sendable, LS, ID: Hashable & Sendable>(
        _ keyPath: WritableKeyPath<GS, C> & Sendable,
        id identifier: KeyPath<LS, ID> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, ID, LS>, Environment>
    where C.Element == LS, C.Index: Sendable {
        .init(action: action, state: .init(collection: lens(keyPath), id: identifier), environment: environment)
    }

    /// Refine the state axis to a keyed collection located by a custom `Hashable` key path (`Lens`).
    public func state<GS, C: MutableCollection & Sendable, LS, ID: Hashable & Sendable>(
        _ container: Lens<GS, C>,
        id identifier: KeyPath<LS, ID> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, ID, LS>, Environment>
    where C.Element == LS, C.Index: Sendable {
        .init(action: action, state: .init(collection: container, id: identifier), environment: environment)
    }

    /// Refine the state axis to a collection keyed by **position** (`WritableKeyPath`).
    public func state<GS, C: MutableCollection & Sendable, LS>(
        indexed keyPath: WritableKeyPath<GS, C> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, C.Index, LS>, Environment>
    where C.Element == LS, C.Index: Hashable & Sendable {
        .init(action: action, state: .init(indexed: lens(keyPath)), environment: environment)
    }

    /// Refine the state axis to a collection keyed by **position** (`Lens`).
    public func state<GS, C: MutableCollection & Sendable, LS>(
        indexed container: Lens<GS, C>
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, C, C.Index, LS>, Environment>
    where C.Element == LS, C.Index: Hashable & Sendable {
        .init(action: action, state: .init(indexed: container), environment: environment)
    }

    /// Refine the state axis to a dictionary keyed by `Key` (`WritableKeyPath`).
    public func state<GS, K: Hashable & Sendable, V: Sendable>(
        dictionary keyPath: WritableKeyPath<GS, [K: V]> & Sendable
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, [K: V], K, V>, Environment> {
        .init(action: action, state: .init(dictionary: lens(keyPath)), environment: environment)
    }

    /// Refine the state axis to a dictionary keyed by `Key` (`Lens`).
    public func state<GS, K: Hashable & Sendable, V: Sendable>(
        dictionary container: Lens<GS, [K: V]>
    ) -> Relay.Scope<Action, Relay.StateAxis.Keyed<GS, [K: V], K, V>, Environment> {
        .init(action: action, state: .init(dictionary: container), environment: environment)
    }
}
