// SPDX-License-Identifier: Apache-2.0

import CoreFP

/// The namespace for the one carrier that re-indexes a feature between a global and a local domain, and
/// the three **axes** it composes. A ``Relay/Scope`` bundles one lane per axis — an action lane
/// (``Relay/ActionAxis``), a state lane (``Relay/StateAxis``), and an environment lane
/// (``Relay/EnvironmentAxis``). Each host (`Reducer.lift`, `StoreType.projection`, `Behavior.lift`)
/// constrains on only the *capabilities* it uses, so a richer scope satisfies every host while a minimal
/// one is compile-locked to just the hosts it fits.
///
/// This collapses the former simplex projection and env-aware lift into a single carrier, and moves the
/// optic/key-path/closure spellings out of the hosts and into the lane witnesses — declared once each —
/// so the many `lift`/`projection` overloads reduce to one method per host.
public enum Relay {
    // MARK: - Action axis (sum type / enum → prism-focused)

    /// The action axis — actions are sum types, so the optic is a prism: `preview` extracts the local
    /// case, `review` embeds it. Hosts constrain on ``ExtractsProtocol`` / ``EmbedsProtocol``.
    public enum ActionAxis {
        /// The base action lane — carries the global/local action types.
        public protocol Transformation: Sendable {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// An action lane that can **extract** the local action (`preview: G → L?`) — a reducer/behavior lift.
        public protocol ExtractsProtocol: Transformation {
            var preview: @Sendable (G) -> L? { get }
        }

        /// An action lane that can **embed** the local action (`review: L → G`) — a store projection / dispatch.
        public protocol EmbedsProtocol: Transformation {
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

        /// The unset marker — the action isn't remapped; the host fills identity. Conforms only the base,
        /// so a host that needs `Extracts`/`Embeds` rejects it and an absent-overload catches it.
        public struct Absent: Transformation {
            public typealias G = Never
            public typealias L = Never
            public init() {}
        }
    }

    // MARK: - State axis (product / struct → lens-focused)

    /// The state axis — state is a product, so the optic is a lens (`get` + `modify`), or affine when the
    /// focus may be absent. Hosts constrain on ``ReadsProtocol`` / ``WritesProtocol``.
    public enum StateAxis {
        /// The base state lane — carries the global/local state types.
        public protocol Transformation: Sendable {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// A state lane that can **totally read** the local state (`get: G → L`) — a store projection.
        public protocol ReadsProtocol: Transformation {
            var get: @Sendable (G) -> L { get }
        }

        /// A state lane that can **write back** — a reducer/behavior lift. Carries both the optional
        /// `preview` (locating the focus, for a behavior's pre-mutation read) and `modify` (the
        /// read-modify-write, skipping when absent). Total and affine witnesses both conform; a behavior
        /// lift reconstructs an `AffineTraversal` from the two, which covers both.
        public protocol WritesProtocol: Transformation {
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

        /// The unset marker — the state isn't remapped; the host fills identity.
        public struct Absent: Transformation {
            public typealias G = Never
            public typealias L = Never
            public init() {}
        }
    }

    // MARK: - Environment axis (reader)

    /// The environment axis — env only ever narrows (`G → L`), so there is a single capability,
    /// ``NarrowsProtocol``. ``Absent`` is the env-free case a reducer/projection use.
    public enum EnvironmentAxis {
        /// The base environment lane.
        public protocol Transformation: Sendable {
            associatedtype G: Sendable
            associatedtype L: Sendable
        }

        /// An environment lane that **narrows** the global environment (`narrow: G → L`) — a behavior lift.
        public protocol NarrowsProtocol: Transformation {
            var narrow: @Sendable (G) -> L { get }
        }

        /// A real environment narrow.
        public struct Narrows<G: Sendable, L: Sendable>: NarrowsProtocol {
            public let narrow: @Sendable (G) -> L
            public init(_ narrow: @escaping @Sendable (G) -> L) { self.narrow = narrow }
            public init(_ keyPath: KeyPath<G, L> & Sendable) { narrow = { $0[keyPath: keyPath] } }
        }

        /// The unset marker — no environment; a reducer/projection ignores env, a behavior lift rejects it.
        public struct Absent: Transformation {
            public typealias G = Never
            public typealias L = Never
            public init() {}
        }
    }

    // MARK: - The carrier

    /// The value that bundles one lane per axis — declared once, applied to whatever a host needs.
    public struct Scope<
        Action: ActionAxis.Transformation,
        State: StateAxis.Transformation,
        Environment: EnvironmentAxis.Transformation
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

extension Relay.Scope where Environment == Relay.EnvironmentAxis.Absent {
    /// Env-free construction — a reducer/projection never reads the environment, so it defaults to
    /// ``Relay/EnvironmentAxis/Absent``. A behavior lift, which needs a real narrow, won't accept the result.
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
        S: Relay.StateAxis.ReadsProtocol,
        E: Relay.EnvironmentAxis.Transformation
    >(
        _ scope: Relay.Scope<A, S, E>
    ) -> StoreProjection<A.L, S.L> where A.G == Action, S.G == State {
        projection(action: scope.action.review, state: scope.state.get)
    }
}
