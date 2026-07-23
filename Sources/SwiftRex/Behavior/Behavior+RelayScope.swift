// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

extension Behavior {
    /// Lift this behavior into a global domain through a ``Relay/Scope`` — the single replacement for the
    /// three-axis `lift(action:state:environment:)` family. Needs the action lane to be **duplex**
    /// (`ExtractsProtocol & EmbedsProtocol` — extract inbound global actions, re-embed emitted ones), the
    /// state lane to **write** (`WritesProtocol`, total or affine), and the environment lane to **narrow**
    /// (`NarrowsProtocol`). It delegates to the per-axis primitives, reconstructing a `Prism` and an
    /// `AffineTraversal` from the lane witnesses (the affine form covers total state too).
    public func lift<
        A: Relay.ActionAxis.ExtractsProtocol & Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.WritesProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol
    >(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, E.Global, E>
    ) -> Behavior<A.Global, S.Global, E.Global> where A.Local == Action, S.Local == State, E.Local == Environment {
        let prism = Prism<A.Global, Action>(preview: scope.action.preview, review: scope.action.review)
        let traversal = AffineTraversal<S.Global, State>(
            preview: scope.state.preview,
            set: { whole, part in
                var copy = whole
                scope.state.modify(&copy) { $0 = part }
                return copy
            }
        )
        return liftAction(prism).liftState(traversal).liftEnvironment(scope.environment.narrow)
    }

    /// Lift this behavior over an **optional** (or otherwise affine) sub-state through a *state-only*
    /// ``Relay/Scope`` — the dedicated host whose action and environment axes must be pass-through
    /// ``Relay/Identity`` (they carry through unchanged) and whose state axis **writes**
    /// (``Relay/StateAxis/Writes``, affine). The compiler enforces the everything-absent-but-state shape.
    /// The 0-or-1 sibling of ``liftCollection(_:)``: while the focus is absent the behavior is a complete
    /// no-op; while present it runs on the **unwrapped** value.
    ///
    /// ```swift
    /// dayBehavior.liftOptional(.state(\AppState.currentDay))   // currentDay: DayDetail.State?
    /// ```
    public func liftOptional<S: Relay.StateAxis.WritesProtocol>(
        _ scope: Relay.Scope<Action, Relay.Identity<Action>, S.Global, S, Environment, Relay.Identity<Environment>>
    ) -> Behavior<Action, S.Global, Environment> where S.Local == State {
        let traversal = AffineTraversal<S.Global, State>(
            preview: scope.state.preview,
            setMut: { whole, part in scope.state.modify(&whole) { $0 = part } }
        )
        return Behavior<Action, S.Global, Environment>(
            // While the focus is absent the inner behavior is skipped entirely — never asked to `handle`,
            // so it neither mutates nor produces effects (stricter than a plain affine state lift).
            handle: { action, context in
                guard let before = context.stateBefore, scope.state.preview(before) != nil else { return .doNothing }
                let c = self.handle(action, context.compactMap(traversal.preview))
                return Reaction(
                    mutation: c.mutation.map { traversal.lift($0) },
                    produce: c.produce.contramapEnvironment { $0.compactMap(traversal.preview) }
                )
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: S.Global) in traversal.preview(state).map { inner($0) } ?? Reader { _ in [] } }
            }
        )
    }
}
