// SPDX-License-Identifier: Apache-2.0

import CoreFP

extension Reducer {
    /// Lift this reducer into a global domain through a ``Relay/Scope`` — the single replacement for the
    /// `lift(action:state:…)` family. A reducer only **extracts** the action (`ExtractsProtocol` — no
    /// `review` needed) and **writes** the state (`WritesProtocol`, total or affine); it has no
    /// environment, so the env slot is pinned sealed (`Never` global) — an inline builder chain
    /// (`.action(…).state(…)`) leaves nothing free. Reconstructs an `AffineTraversal` from the state lane
    /// (covers total and affine).
    public func lift<
        A: Relay.ActionAxis.ExtractsProtocol,
        S: Relay.StateAxis.WritesProtocol
    >(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, Never, Relay.Absurd<Never>>
    ) -> Reducer<A.Global, S.Global> where A.Local == ActionType, S.Local == StateType {
        lifted(through: scope)
    }

    /// Lift this reducer through a **declared** ``Relay/Scope`` — the environment axis is fully generic
    /// and ignored, so the one duplex scope a feature declares (`ScopeOf<AppFeature>.action(…)…`, env
    /// pass-through or a real narrow) also lifts its reducer.
    public func lift<
        A: Relay.ActionAxis.ExtractsProtocol,
        S: Relay.StateAxis.WritesProtocol,
        GE, E: Relay.EnvironmentAxis.Strategy
    >(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global> where A.Local == ActionType, S.Local == StateType {
        lifted(through: scope)
    }

    private func lifted<
        A: Relay.ActionAxis.ExtractsProtocol,
        S: Relay.StateAxis.WritesProtocol,
        GE, E: Relay.EnvironmentAxis.Strategy
    >(
        through scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global> where A.Local == ActionType, S.Local == StateType {
        let traversal = AffineTraversal<S.Global, StateType>(
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
