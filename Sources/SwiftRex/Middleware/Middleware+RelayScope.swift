// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

extension Middleware {
    /// Lift this middleware into a global domain through a ``Relay/Scope`` — the single replacement for
    /// the three-axis `lift(action:state:environment:)` family. A middleware **reads** state (never
    /// mutates it), so it needs a **duplex** action lane, a **reading** state lane (`ReadsProtocol`), and
    /// a **narrowing** environment lane; it delegates to the per-axis primitives.
    public func lift<
        A: Relay.ActionAxis.ExtractsProtocol & Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.ReadsProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol
    >(
        _ scope: Relay.Scope<A, S, E>
    ) -> Middleware<A.G, S.G, E.G> where A.L == Action, S.L == State, E.L == Environment {
        let prism = Prism<A.G, Action>(preview: scope.action.preview, review: scope.action.review)
        return liftAction(prism).liftState(scope.state.get).liftEnvironment(scope.environment.narrow)
    }

    /// Lift this middleware over an **optional** (or otherwise affine) sub-state through a *state-only*
    /// ``Relay/Scope`` — the dedicated host whose action and environment axes must be ``Relay/ActionAxis/Absent``
    /// and ``Relay/EnvironmentAxis/Absent`` and whose state axis **writes** (``Relay/StateAxis/Writes``,
    /// affine). Middleware only reads through it (via the affine `preview`); while the focus is absent it is
    /// skipped entirely.
    ///
    /// ```swift
    /// dayMiddleware.liftOptional(.state(\AppState.currentDay))   // currentDay: DayDetail.State?
    /// ```
    public func liftOptional<S: Relay.StateAxis.WritesProtocol>(
        _ scope: Relay.Scope<Relay.ActionAxis.Absent, S, Relay.EnvironmentAxis.Absent>
    ) -> Middleware<Action, S.G, Environment> where S.L == State {
        let traversal = AffineTraversal<S.G, State>(
            preview: scope.state.preview,
            setMut: { whole, part in scope.state.modify(&whole) { $0 = part } }
        )
        return Middleware<Action, S.G, Environment>(
            // While the focus is absent the inner middleware is skipped entirely — no effect is produced.
            handle: { action, context in
                guard let before = context.stateBefore, scope.state.preview(before) != nil else { return Reader { _ in .empty } }
                return self.handle(action, context.compactMap(traversal.preview))
                    .contramapEnvironment { $0.compactMap(traversal.preview) }
            },
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (state: S.G) in traversal.preview(state).map { inner($0) } ?? Reader { _ in [] } }
            }
        )
    }
}
