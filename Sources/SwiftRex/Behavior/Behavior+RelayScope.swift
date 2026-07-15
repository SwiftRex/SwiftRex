// SPDX-License-Identifier: Apache-2.0

import CoreFP

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
        _ scope: Relay.Scope<A, S, E>
    ) -> Behavior<A.G, S.G, E.G> where A.L == Action, S.L == State, E.L == Environment {
        let prism = Prism<A.G, Action>(preview: scope.action.preview, review: scope.action.review)
        let traversal = AffineTraversal<S.G, State>(
            preview: scope.state.preview,
            set: { whole, part in
                var copy = whole
                scope.state.modify(&copy) { $0 = part }
                return copy
            }
        )
        return liftAction(prism).liftState(traversal).liftEnvironment(scope.environment.narrow)
    }
}
