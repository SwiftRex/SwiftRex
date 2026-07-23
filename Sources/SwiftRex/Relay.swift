// SPDX-License-Identifier: Apache-2.0

import CoreFP

/// The namespace for the one carrier that re-indexes a feature between a global and a local domain, and
/// the three **axes** it composes. A ``Relay/Scope`` bundles one lane per axis — an action lane
/// (``Relay/ActionAxis``), a state lane (``Relay/StateAxis``), and an environment lane
/// (``Relay/EnvironmentAxis``) — and re-exports each lane's **global** type as its own generic parameter,
/// so the concrete entry alias ``ScopeOf`` can pin all three roots and leave the strategies to inference:
///
/// ```swift
/// static let child = ScopeOf<AppFeature>.action(\.child).state(\.child).environment(\.childEnv)
/// ```
///
/// Each host (`Reducer.lift`, `StoreType.projection`, `Behavior.lift`) constrains on only the
/// *capabilities* it uses, so a richer scope satisfies every host while a minimal one is compile-locked to
/// just the hosts it fits.
///
/// Each axis is a small protocol tower rather than one flat protocol, so the *builder* and *hosts* can
/// grant methods purely by conformance — no `@available` suppression:
///
/// ```
/// …Axis.Strategy            the slot type — everything an axis can be (carries `Global`; Scope binds here)
/// └─ …Axis.Transformation   a real, present axis (NOT Absurd)
///    ├─ …Axis.IdentityProtocol   pass-through (local == global) — the fluent INSTANCE refiner
///    └─ …Axis.LiftingProtocol    carries `Local` + capability — the static FACTORY entry
///       └─ ExtractsProtocol / EmbedsProtocol / ReadsProtocol / WritesProtocol / NarrowsProtocol
/// ```
///
/// Two shared markers cover the non-lifting cases across every axis: ``Relay/Identity`` (pass-through)
/// and ``Relay/Absurd`` (sealed — the axis does not exist for this host, so it offers neither factory nor
/// instance builder). Both are generic over the axis' `Global` only — `(Global) -> Global` is their shape.
/// Because `Absurd` conforms only to the axis `Strategy` base and **not** `Transformation`, it structurally
/// has no builder method — nothing to suppress.
public enum Relay {
    // MARK: - Action axis (sum type / enum → prism-focused)

    /// The action axis — actions are sum types, so the optic is a prism: `preview` extracts the local
    /// case, `review` embeds it. Hosts constrain on ``ExtractsProtocol`` / ``EmbedsProtocol``.
    public enum ActionAxis {
        /// Everything the action lane can be — the ``Relay/Scope`` action slot binds here, so both the
        /// ``Relay/Absurd`` seal and any real lane are legal, and a *state* lane is not. Carries the
        /// **global** action type, which ``Relay/Scope`` re-exports as its own `Action` parameter.
        public protocol Strategy: Sendable {
            associatedtype Global: Sendable
        }

        /// A **present** action lane (identity or lifting) — i.e. not ``Relay/Absurd``.
        public protocol Transformation: Strategy {}

        /// The pass-through action lane (`local == global`) — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}

        /// A real action lane — carries the local action type and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype Local: Sendable
        }

        /// An action lane that can **extract** the local action (`preview: Global → Local?`) — a reducer/behavior lift.
        public protocol ExtractsProtocol: LiftingProtocol {
            var preview: @Sendable (Global) -> Local? { get }
        }

        /// An action lane that can **embed** the local action (`review: Local → Global`) — a store projection / dispatch.
        public protocol EmbedsProtocol: LiftingProtocol {
            var review: @Sendable (Local) -> Global { get }
        }

        /// Extract-only witness. The minimum a reducer lift needs.
        public struct Extracts<Global: Sendable, Local: Sendable>: ExtractsProtocol {
            public let preview: @Sendable (Global) -> Local?
            public init(_ preview: @escaping @Sendable (Global) -> Local?) { self.preview = preview }
            public init(_ prism: CoreFP.Prism<Global, Local>) { preview = prism.preview }
            public init(_ keyPath: PrismKeyPath<Global, Local>) { preview = CoreFP.Prism(keyPath).preview }
        }

        /// Embed-only witness. The minimum a store projection needs.
        public struct Embeds<Global: Sendable, Local: Sendable>: EmbedsProtocol {
            public let review: @Sendable (Local) -> Global
            public init(_ review: @escaping @Sendable (Local) -> Global) { self.review = review }
            public init(_ prism: CoreFP.Prism<Global, Local>) { review = prism.review }
            public init(_ keyPath: PrismKeyPath<Global, Local>) { review = CoreFP.Prism(keyPath).review }
        }

        /// Duplex witness (`preview` **and** `review`) — satisfies either host.
        public struct Prism<Global: Sendable, Local: Sendable>: ExtractsProtocol, EmbedsProtocol {
            public let preview: @Sendable (Global) -> Local?
            public let review: @Sendable (Local) -> Global
            public init(_ prism: CoreFP.Prism<Global, Local>) { preview = prism.preview; review = prism.review }
            public init(_ keyPath: PrismKeyPath<Global, Local>) {
                let prism = CoreFP.Prism(keyPath)
                preview = prism.preview
                review = prism.review
            }
            public init(preview: @escaping @Sendable (Global) -> Local?, review: @escaping @Sendable (Local) -> Global) {
                self.preview = preview
                self.review = review
            }
        }
    }

    // MARK: - State axis (product / struct → lens-focused)

    /// The state axis — state is a product, so the optic is a lens (`get` + `modify`), or affine when the
    /// focus may be absent. Hosts constrain on ``ReadsProtocol`` / ``WritesProtocol``.
    public enum StateAxis {
        /// Everything the state lane can be — the ``Relay/Scope`` state slot binds here. Carries the
        /// **global** state type, which ``Relay/Scope`` re-exports as its own `State` parameter.
        public protocol Strategy: Sendable {
            associatedtype Global: Sendable
        }
        /// A **present** state lane (identity or lifting).
        public protocol Transformation: Strategy {}
        /// The pass-through state lane — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}
        /// A real state lane — carries the local state type and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype Local: Sendable
        }

        /// A state lane that can **totally read** the local state (`get: Global → Local`) — a store projection.
        public protocol ReadsProtocol: LiftingProtocol {
            var get: @Sendable (Global) -> Local { get }
        }

        /// A state lane that can **write back** — a reducer/behavior lift. Carries both the optional
        /// `preview` (locating the focus, for a behavior's pre-mutation read) and `modify` (the
        /// read-modify-write, skipping when absent). Total and affine witnesses both conform; a behavior
        /// lift reconstructs an `AffineTraversal` from the two, which covers both.
        public protocol WritesProtocol: LiftingProtocol {
            var preview: @Sendable (Global) -> Local? { get }
            var modify: @Sendable (inout Global, (inout Local) -> Void) -> Void { get }
        }

        /// Read-only witness (total). Serves a projection; a reducer can't write through it.
        public struct Reads<Global: Sendable, Local: Sendable>: ReadsProtocol {
            public let get: @Sendable (Global) -> Local
            public init(_ get: @escaping @Sendable (Global) -> Local) { self.get = get }
            public init(_ keyPath: KeyPath<Global, Local> & Sendable) { get = { $0[keyPath: keyPath] } }
            public init(_ lens: Lens<Global, Local>) { get = lens.get }
        }

        /// Affine write-with-skip witness (the `liftOptional` / enum-case case). Serves reducer/behavior.
        public struct Writes<Global: Sendable, Local: Sendable>: WritesProtocol {
            public let preview: @Sendable (Global) -> Local?
            public let modify: @Sendable (inout Global, (inout Local) -> Void) -> Void
            public init(_ affine: AffineTraversal<Global, Local>) { preview = affine.preview; modify = affine.tryModifyMut }
            public init(_ prism: CoreFP.Prism<Global, Local>) { preview = prism.preview; modify = prism.tryModifyMut }
            public init(_ keyPath: WritableKeyPath<Global, Local?> & Sendable) {
                preview = { $0[keyPath: keyPath] }
                modify = { whole, transform in
                    guard var part = whole[keyPath: keyPath] else { return }
                    transform(&part)
                    whole[keyPath: keyPath] = part
                }
            }
        }

        /// Total-lens witness — reads **and** writes. Serves a projection *and* a reducer/behavior.
        public struct ReadsWrites<Global: Sendable, Local: Sendable>: ReadsProtocol, WritesProtocol {
            public let get: @Sendable (Global) -> Local
            public let preview: @Sendable (Global) -> Local?
            public let modify: @Sendable (inout Global, (inout Local) -> Void) -> Void
            public init(_ lens: Lens<Global, Local>) { get = lens.get; preview = { lens.get($0) }; modify = lens.modifyMut }
            public init(_ keyPath: WritableKeyPath<Global, Local> & Sendable) {
                get = { $0[keyPath: keyPath] }
                preview = { $0[keyPath: keyPath] }
                modify = { whole, transform in transform(&whole[keyPath: keyPath]) }
            }
        }
    }

    // MARK: - Environment axis (reader)

    /// The environment axis — env only ever narrows (`Global → Local`), so there is a single capability,
    /// ``NarrowsProtocol``. ``Relay/Identity`` / ``Relay/Absurd`` cover the env-free cases.
    public enum EnvironmentAxis {
        /// Everything the environment lane can be — the ``Relay/Scope`` environment slot binds here.
        /// Carries the **global** environment type, re-exported as Scope's `Environment` parameter.
        public protocol Strategy: Sendable {
            associatedtype Global: Sendable
        }
        /// A **present** environment lane (identity or lifting).
        public protocol Transformation: Strategy {}
        /// The pass-through environment lane — grants the fluent **instance** refiner.
        public protocol IdentityProtocol: Transformation {}
        /// A real environment lane — carries the local env type and grants the static **factory**.
        public protocol LiftingProtocol: Transformation {
            associatedtype Local: Sendable
        }

        /// An environment lane that **narrows** the global environment (`narrow: Global → Local`) — a behavior lift.
        public protocol NarrowsProtocol: LiftingProtocol {
            var narrow: @Sendable (Global) -> Local { get }
        }

        /// A real environment narrow.
        public struct Narrows<Global: Sendable, Local: Sendable>: NarrowsProtocol {
            public let narrow: @Sendable (Global) -> Local
            public init(_ narrow: @escaping @Sendable (Global) -> Local) { self.narrow = narrow }
            public init(_ keyPath: KeyPath<Global, Local> & Sendable) { narrow = { $0[keyPath: keyPath] } }
        }
    }

    // MARK: - Shared axis-agnostic markers

    /// A marker an un-set builder axis can be **filled with**, chosen by the host's expected type: a lift
    /// leaves un-set axes ``Relay/Identity`` (chainable), an action-only `.on` seals them ``Relay/Absurd``.
    /// Both are default-constructible; a real witness is not, so it can never be an un-set default.
    public protocol AxisDefault: Sendable {
        init()
    }

    /// Pass-through on any axis — `local == global`, `{ $0 }`. Generic over that `Global` only (it stores
    /// nothing). Conforms to every axis' `IdentityProtocol`, so one type serves all three slots, and grants
    /// the fluent **instance** refiner (you may still specialise this axis).
    public struct Identity<Global: Sendable>:
        ActionAxis.IdentityProtocol, StateAxis.IdentityProtocol, EnvironmentAxis.IdentityProtocol, AxisDefault {
        public init() {}
    }

    /// The **sealed** marker — this axis does not exist for this host (e.g. the state/env of an action-only
    /// `.on` bridge). Generic over the phantom `Global` its slot re-exports (`Never` when the host has no
    /// such type at all). Conforms only to each axis' `Strategy` base (**not** `Transformation`), so it
    /// structurally has no factory and no instance refiner — no `@available` needed.
    public struct Absurd<Global: Sendable>:
        ActionAxis.Strategy, StateAxis.Strategy, EnvironmentAxis.Strategy, AxisDefault {
        public init() {}
    }

    // MARK: - The carrier

    /// The value that bundles one lane per axis — declared once, applied to whatever a host needs. Each
    /// axis contributes two parameters: its **global** type and its **strategy** (whose `Global` matches
    /// it), so an alias like ``ScopeOf`` can pin the three roots and leave the strategies to inference.
    /// A lane may be a real witness, ``Relay/Identity`` (pass-through), or ``Relay/Absurd`` (sealed), and
    /// lanes can't cross axes.
    ///
    /// The `Strategy.Global == Global` coherence is **not** a type-level `where` clause — a typealias
    /// requirement is checked eagerly (rejecting `_` holes at use sites and blocking ``ScopeOf``'s
    /// declaration). It is enforced by the only initializer instead (see the extension below): an
    /// incoherent specialization is nameable but unconstructible.
    public struct Scope<
        Action: Sendable,
        ActionStrategy: ActionAxis.Strategy,
        State: Sendable,
        StateStrategy: StateAxis.Strategy,
        Environment: Sendable,
        EnvironmentStrategy: EnvironmentAxis.Strategy
    >: Sendable {
        /// The action lane.
        public let action: ActionStrategy
        /// The state lane.
        public let state: StateStrategy
        /// The environment lane.
        public let environment: EnvironmentStrategy
    }
}

extension Relay.Scope where
    ActionStrategy.Global == Action,
    StateStrategy.Global == State,
    EnvironmentStrategy.Global == Environment {
    /// The one way to construct a scope — constrained so every lane's `Global` matches the slot the
    /// carrier re-exports for it.
    public init(action: ActionStrategy, state: StateStrategy, environment: EnvironmentStrategy) {
        self.action = action
        self.state = state
        self.environment = environment
    }
}

extension Relay.Scope where
    ActionStrategy.Global == Action,
    StateStrategy.Global == State,
    Environment == Never,
    EnvironmentStrategy == Relay.Absurd<Never> {
    /// Env-free construction — a reducer/projection never reads the environment, so the env slot is
    /// sealed (`Never` global), matching the env-less hosts. A behavior lift, which needs a real narrow,
    /// won't accept the result.
    public init(action: ActionStrategy, state: StateStrategy) {
        self.init(action: action, state: state, environment: .init())
    }
}

extension StoreType {
    /// Project this store through a ``Relay/Scope`` into a narrower ``StoreProjection``. Needs the action
    /// lane to **embed** and the state lane to **totally read**. An affine state lane
    /// (``Relay/StateAxis/Writes``) or an extract-only action lane won't compile here.
    ///
    /// The **inline** form: `StoreType` has no environment, so the env slot is pinned sealed
    /// (`Never` global) — an inline builder chain (`.action(…).state(…)`) leaves nothing free.
    @MainActor
    public func projection<
        A: Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.ReadsProtocol
    >(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>
    ) -> StoreProjection<A.Local, S.Local> where A.Global == Action, S.Global == State {
        projection(action: scope.action.review, state: scope.state.get)
    }

    /// Project this store through a **declared** ``Relay/Scope`` — the environment axis is fully generic
    /// and ignored, so the one duplex scope a feature declares (`ScopeOf<AppFeature>.action(…)…`, env
    /// pass-through or a real narrow) also serves the projection.
    @MainActor
    public func projection<
        A: Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.ReadsProtocol,
        GE, E: Relay.EnvironmentAxis.Strategy
    >(
        _ scope: Relay.Scope<Action, A, State, S, GE, E>
    ) -> StoreProjection<A.Local, S.Local> where A.Global == Action, S.Global == State {
        projection(action: scope.action.review, state: scope.state.get)
    }
}
