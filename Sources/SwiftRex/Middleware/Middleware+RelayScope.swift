// SPDX-License-Identifier: Apache-2.0

import CoreFP

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
}
