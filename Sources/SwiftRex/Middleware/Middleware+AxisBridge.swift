// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Cross-feature routing (`.on`) — axis-separated
//
// The middleware counterpart of `Behavior.on`. A middleware is read-only on state, so its routing has no
// `reduce`: a **trigger** (`.action(…)` — an `Extracts` previewing the payload) is embedded into an
// outbound action (`.action(…)`), optionally guarded by a `when` predicate. State is read only to
// evaluate the guard.

extension Middleware {
    // The routing core; public entry points build `out` from an `.action(…)` embed (no bare closures).
    private func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        when condition: (@Sendable (State) -> Bool)? = nil
    ) -> Self {
        .combine(self, Middleware { action, context in
            guard let value = trigger.preview(action) else { return Reader { _ in .empty } }
            let stateBefore = context.stateBefore
            return Reader { _ in
                if let condition {
                    guard let state = stateBefore, condition(state) else { return .empty }
                }
                return Effect.just(out(value))
            }
        })
    }

    /// Route the trigger's payload by **embedding** it into an outbound action, optionally guarded.
    public func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        dispatch out: Relay.ActionAxis.Embeds<Action, T>,
        when condition: (@Sendable (State) -> Bool)? = nil
    ) -> Self {
        on(trigger, dispatch: out.review, when: condition)
    }
}
