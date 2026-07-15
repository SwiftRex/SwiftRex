// SPDX-License-Identifier: Apache-2.0

import CoreFP

extension Reducer {
    /// Lift this reducer into a global domain through a ``Relay/Scope`` — the single replacement for the
    /// `lift(action:state:…)` family. A reducer only **extracts** the action (`ExtractsProtocol` — no
    /// `review` needed) and **writes** the state (`WritesProtocol`, total or affine); the environment
    /// lane is ignored. Reconstructs an `AffineTraversal` from the state lane (covers total and affine).
    public func lift<
        A: Relay.ActionAxis.ExtractsProtocol,
        S: Relay.StateAxis.WritesProtocol,
        E: Relay.EnvironmentAxis.Transformation
    >(
        _ scope: Relay.Scope<A, S, E>
    ) -> Reducer<A.G, S.G> where A.L == ActionType, S.L == StateType {
        let traversal = AffineTraversal<S.G, StateType>(
            preview: scope.state.preview,
            set: { whole, part in
                var copy = whole
                scope.state.modify(&copy) { $0 = part }
                return copy
            }
        )
        return .reduce { globalAction in
            guard let localAction = scope.action.preview(globalAction) else { return .identity }
            return traversal.lift(self.reduce(localAction))
        }
    }
}
