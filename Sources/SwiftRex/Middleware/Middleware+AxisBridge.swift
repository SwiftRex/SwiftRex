// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Cross-feature routing (`.on`) — axis-separated
//
// The middleware counterpart of `Behavior.on`. A middleware is read-only on state, so its routing has no
// `reduce`: a **trigger** (`.action(…)` — an `Extracts` previewing the payload) is embedded into an
// outbound action (`.action(…)`), optionally guarded by a `when` predicate (right after the trigger, since
// it gates the routing). State is read only to evaluate the guard.

extension Middleware {
    /// Route the trigger's payload by **embedding** it into an outbound action, optionally guarded by
    /// `when` (which sits right after the trigger, gating the routing).
    public func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        when condition: (@Sendable (State) -> Bool)? = nil,
        dispatch out: Relay.ActionAxis.Embeds<Action, T>
    ) -> Self {
        .combine(self, Middleware { action, context in
            guard let value = trigger.preview(action) else { return Reader { _ in .empty } }
            let stateBefore = context.stateBefore
            return Reader { _ in
                if let condition {
                    guard let state = stateBefore, condition(state) else { return .empty }
                }
                return Effect.just(out.review(value))
            }
        })
    }
}
