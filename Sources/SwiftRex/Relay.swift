// SPDX-License-Identifier: Apache-2.0

import CoreFP

/// The namespace for the one carrier that re-indexes a feature between a global and a local domain, and
/// the three **axes** it composes. A ``Relay/Scope`` bundles one lane per axis — an action lane
/// (``Relay/ActionAxis``), a state lane (``Relay/StateAxis``), and an environment lane
/// (``Relay/EnvironmentAxis``). Each host (`Reducer.lift`, `StoreType.projection`, `Behavior.lift`)
/// constrains on only the *capabilities* it uses, so a richer scope satisfies every host while a minimal
/// one is compile-locked to just the hosts it fits.
///
/// Each axis is a small protocol tower rather than one flat protocol, so the *builder* and *hosts* can
/// grant methods purely by conformance — no `@available` suppression:
///
/// ```
/// …Axis.Strategy            the slot type — everything an axis can be (Scope binds here)
/// └─ …Axis.Transformation   a real, present axis (NOT Absurd)
///    ├─ …Axis.IdentityProtocol   pass-through (local == global) — the fluent INSTANCE refiner
///    └─ …Axis.LiftingProtocol    carries G/L + capability — the static FACTORY entry
///       └─ ExtractsProtocol / EmbedsProtocol / ReadsProtocol / WritesProtocol / NarrowsProtocol
/// ```
///
/// Two shared, param-less markers cover the non-lifting cases across every axis: ``Relay/Identity``
/// (pass-through) and ``Relay/Absurd`` (sealed — the axis does not exist for this host, so it offers
/// neither factory nor instance builder). Because `Absurd` conforms only to the axis `Strategy` base and
/// **not** `Transformation`, it structurally has no builder method — nothing to suppress.
public enum Relay {
    // MARK: - Action axis (sum type / enum → prism-focused)

    /// The action axis — actions are sum types, so the optic is a prism: `preview` extracts the local
    /// case, `review` embeds it. Hosts constrain on ``ExtractsProtocol`` / ``EmbedsProtocol``.
    public enum ActionAxis {
        /// Everything the action lane can be — the ``Relay/Scope`` action slot binds here, so both the
        /// ``Relay/Absurd`` seal and any real lane are legal, and a *state* lane is not.
        public protocol Strategy: Sendable {}

        /// A **present** action lane (identity or lifting) — i.e. not ``Relay/Absurd``.
        public protocol Transformation: Strategy {}

        /// The pass-through action lane (`local == global`) — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}

        /// A real action lane — carries the global/local action types and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// An action lane that can **extract** the local action (`preview: G → L?`) — a reducer/behavior lift.
        public protocol ExtractsProtocol: LiftingProtocol {
            var preview: @Sendable (G) -> L? { get }
        }

        /// An action lane that can **embed** the local action (`review: L → G`) — a store projection / dispatch.
        public protocol EmbedsProtocol: LiftingProtocol {
            var review: @Sendable (L) -> G { get }
        }

        /// Extract-only witness. The minimum a reducer lift needs.
        public struct Extracts<G: Sendable, L: Sendable>: ExtractsProtocol {
            public let preview: @Sendable (G) -> L?
            public init(_ preview: @escaping @Sendable (G) -> L?) { self.preview = preview }
            public init(_ prism: CoreFP.Prism<G, L>) { preview = prism.preview }
            public init(_ keyPath: PrismKeyPath<G, L>) { preview = CoreFP.Prism(keyPath).preview }
        }

        /// Embed-only witness. The minimum a store projection needs.
        public struct Embeds<G: Sendable, L: Sendable>: EmbedsProtocol {
            public let review: @Sendable (L) -> G
            public init(_ review: @escaping @Sendable (L) -> G) { self.review = review }
            public init(_ prism: CoreFP.Prism<G, L>) { review = prism.review }
            public init(_ keyPath: PrismKeyPath<G, L>) { review = CoreFP.Prism(keyPath).review }
        }

        /// Duplex witness (`preview` **and** `review`) — satisfies either host.
        public struct Prism<G: Sendable, L: Sendable>: ExtractsProtocol, EmbedsProtocol {
            public let preview: @Sendable (G) -> L?
            public let review: @Sendable (L) -> G
            public init(_ prism: CoreFP.Prism<G, L>) { preview = prism.preview; review = prism.review }
            public init(_ keyPath: PrismKeyPath<G, L>) {
                let prism = CoreFP.Prism(keyPath)
                preview = prism.preview
                review = prism.review
            }
            public init(preview: @escaping @Sendable (G) -> L?, review: @escaping @Sendable (L) -> G) {
                self.preview = preview
                self.review = review
            }
        }
    }

    // MARK: - State axis (product / struct → lens-focused)

    /// The state axis — state is a product, so the optic is a lens (`get` + `modify`), or affine when the
    /// focus may be absent. Hosts constrain on ``ReadsProtocol`` / ``WritesProtocol``.
    public enum StateAxis {
        /// Everything the state lane can be — the ``Relay/Scope`` state slot binds here.
        public protocol Strategy: Sendable {}
        /// A **present** state lane (identity or lifting).
        public protocol Transformation: Strategy {}
        /// The pass-through state lane — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}
        /// A real state lane — carries the global/local state types and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// A state lane that can **totally read** the local state (`get: G → L`) — a store projection.
        public protocol ReadsProtocol: LiftingProtocol {
            var get: @Sendable (G) -> L { get }
        }

        /// A state lane that can **write back** — a reducer/behavior lift. Carries both the optional
        /// `preview` (locating the focus, for a behavior's pre-mutation read) and `modify` (the
        /// read-modify-write, skipping when absent). Total and affine witnesses both conform; a behavior
        /// lift reconstructs an `AffineTraversal` from the two, which covers both.
        public protocol WritesProtocol: LiftingProtocol {
            var preview: @Sendable (G) -> L? { get }
            var modify: @Sendable (inout G, (inout L) -> Void) -> Void { get }
        }

        /// Read-only witness (total). Serves a projection; a reducer can't write through it.
        public struct Reads<G: Sendable, L: Sendable>: ReadsProtocol {
            public let get: @Sendable (G) -> L
            public init(_ get: @escaping @Sendable (G) -> L) { self.get = get }
            public init(_ keyPath: KeyPath<G, L> & Sendable) { get = { $0[keyPath: keyPath] } }
            public init(_ lens: Lens<G, L>) { get = lens.get }
        }

        /// Affine write-with-skip witness (the `liftOptional` / enum-case case). Serves reducer/behavior.
        public struct Writes<G: Sendable, L: Sendable>: WritesProtocol {
            public let preview: @Sendable (G) -> L?
            public let modify: @Sendable (inout G, (inout L) -> Void) -> Void
            public init(_ affine: AffineTraversal<G, L>) { preview = affine.preview; modify = affine.tryModifyMut }
            public init(_ prism: CoreFP.Prism<G, L>) { preview = prism.preview; modify = prism.tryModifyMut }
            public init(_ keyPath: WritableKeyPath<G, L?> & Sendable) {
                preview = { $0[keyPath: keyPath] }
                modify = { whole, transform in
                    guard var part = whole[keyPath: keyPath] else { return }
                    transform(&part)
                    whole[keyPath: keyPath] = part
                }
            }
        }

        /// Total-lens witness — reads **and** writes. Serves a projection *and* a reducer/behavior.
        public struct ReadsWrites<G: Sendable, L: Sendable>: ReadsProtocol, WritesProtocol {
            public let get: @Sendable (G) -> L
            public let preview: @Sendable (G) -> L?
            public let modify: @Sendable (inout G, (inout L) -> Void) -> Void
            public init(_ lens: Lens<G, L>) { get = lens.get; preview = { lens.get($0) }; modify = lens.modifyMut }
            public init(_ keyPath: WritableKeyPath<G, L> & Sendable) {
                get = { $0[keyPath: keyPath] }
                preview = { $0[keyPath: keyPath] }
                modify = { whole, transform in transform(&whole[keyPath: keyPath]) }
            }
        }
    }

    // MARK: - Environment axis (reader)

    /// The environment axis — env only ever narrows (`G → L`), so there is a single capability,
    /// ``NarrowsProtocol``. ``Relay/Identity`` / ``Relay/Absurd`` cover the env-free cases.
    public enum EnvironmentAxis {
        /// Everything the environment lane can be — the ``Relay/Scope`` environment slot binds here.
        public protocol Strategy: Sendable {}
        /// A **present** environment lane (identity or lifting).
        public protocol Transformation: Strategy {}
        /// The pass-through environment lane — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}
        /// A real environment lane — carries the global/local env types and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// An environment lane that **narrows** the global environment (`narrow: G → L`) — a behavior lift.
        public protocol NarrowsProtocol: LiftingProtocol {
            var narrow: @Sendable (G) -> L { get }
        }

        /// A real environment narrow.
        public struct Narrows<G: Sendable, L: Sendable>: NarrowsProtocol {
            public let narrow: @Sendable (G) -> L
            public init(_ narrow: @escaping @Sendable (G) -> L) { self.narrow = narrow }
            public init(_ keyPath: KeyPath<G, L> & Sendable) { narrow = { $0[keyPath: keyPath] } }
        }
    }

    // MARK: - Shared axis-agnostic markers

    /// A marker an un-set builder axis can be **filled with**, chosen by the host's expected type: a lift
    /// leaves un-set axes ``Relay/Identity`` (chainable), an action-only `.on` seals them ``Relay/Absurd``.
    /// Both are default-constructible; a real witness is not, so it can never be an un-set default.
    public protocol AxisDefault: Sendable {
        init()
    }

    /// Pass-through on any axis — `local == global`, `{ $0 }`. Conforms to every axis' `IdentityProtocol`,
    /// so one value serves all three slots. Grants the fluent **instance** refiner (you may still
    /// specialise this axis); a host derives the pass-through global from `self`, so it carries nothing.
    public struct Identity:
        ActionAxis.IdentityProtocol, StateAxis.IdentityProtocol, EnvironmentAxis.IdentityProtocol, AxisDefault {
        public init() {}
    }

    /// The **sealed** marker — this axis does not exist for this host (e.g. the state/env of an action-only
    /// `.on` bridge). Conforms only to each axis' `Strategy` base (**not** `Transformation`), so it
    /// structurally has no factory and no instance refiner — no `@available` needed.
    public struct Absurd:
        ActionAxis.Strategy, StateAxis.Strategy, EnvironmentAxis.Strategy, AxisDefault {
        public init() {}
    }

    // MARK: - The carrier

    /// The value that bundles one lane per axis — declared once, applied to whatever a host needs. Each
    /// slot binds to its axis' `Strategy`, so a lane may be a real witness, ``Relay/Identity``
    /// (pass-through), or ``Relay/Absurd`` (sealed), and lanes can't cross axes.
    public struct Scope<
        Action: ActionAxis.Strategy,
        State: StateAxis.Strategy,
        Environment: EnvironmentAxis.Strategy
    >: Sendable {
        /// The action lane.
        public let action: Action
        /// The state lane.
        public let state: State
        /// The environment lane.
        public let environment: Environment

        public init(action: Action, state: State, environment: Environment) {
            self.action = action
            self.state = state
            self.environment = environment
        }
    }
}

extension Relay.Scope where Environment == Relay.Identity {
    /// Env-free construction — a reducer/projection never reads the environment, so it defaults to
    /// pass-through ``Relay/Identity``. A behavior lift, which needs a real narrow, won't accept the result.
    public init(action: Action, state: State) {
        self.init(action: action, state: state, environment: .init())
    }
}

extension StoreType {
    /// Project this store through a ``Relay/Scope`` into a narrower ``StoreProjection``. Needs the action
    /// lane to **embed** and the state lane to **totally read**; the environment lane is ignored. An
    /// affine state lane (``Relay/StateAxis/Writes``) or an extract-only action lane won't compile here.
    @MainActor
    public func projection<
        A: Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.ReadsProtocol
    >(
        _ scope: Relay.Scope<A, S, Relay.Identity>
    ) -> StoreProjection<A.L, S.L> where A.G == Action, S.G == State {
        projection(action: scope.action.review, state: scope.state.get)
    }
}
