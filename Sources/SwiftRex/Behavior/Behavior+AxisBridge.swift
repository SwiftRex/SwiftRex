// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Cross-feature routing (`.on`) — axis-separated
//
// One shape collapses the routing family: a **trigger** (`.action(…)` — an `Extracts` that previews the
// payload from the action), an optional **`when`** guard, an optional **dispatch** (`.action(…)` embed),
// and an optional **reduce** (co-located state mutation). `when` comes right after the trigger because it
// gates the **whole** routing — both the dispatch and the reduce — not just the mutation. State is never
// touched unless the trigger matches (and the guard passes); with no `reduce`, the mutation is
// `.unchanged`, so a routing-only `.on` never copies state.
//
//     .on(.action(\.didLoad), dispatch: .action(\.renderItems))
//     .on(.action(\.didLoad), dispatch: .action { .renderItems($0) }, reduce: { items, s in s.items = items })
//     .on(.action(\.retry), when: { $0.attempts < 3 }, reduce: { _, s in s.attempts += 1 })

extension Behavior {
    /// Route the trigger's payload by **embedding** it into an outbound action (`.action(…)`), optionally
    /// mutating state (`reduce:`). The optional **`when`** guard gates the whole routing — dispatch and
    /// reduce alike — which is why it sits right after the trigger.
    public func on<T: Sendable, Trigger: Relay.ActionAxis.ExtractsProtocol, Dispatch: Relay.ActionAxis.EmbedsProtocol>(
        _ trigger: Relay.Scope<Action, Trigger, State, Relay.Absurd<State>, Environment, Relay.Absurd<Environment>>,
        when condition: (@Sendable (State) -> Bool)? = nil,
        dispatch out: Relay.Scope<Action, Dispatch, State, Relay.Absurd<State>, Environment, Relay.Absurd<Environment>>,
        reduce: (@Sendable (T, inout State) -> Void)? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Self where Trigger.Global == Action, Trigger.Local == T, Dispatch.Global == Action, Dispatch.Local == T {
        .combine(self, Behavior { action, context in
            guard let value = trigger.action.preview(action) else { return .doNothing }
            if let condition {
                guard let state = context.stateBefore, condition(state) else { return .doNothing }
            }
            let mutation: ReducerOutcome<State> = reduce.map { reduce in
                .mutation(EndoMut { state in reduce(value, &state) })
            } ?? .unchanged
            // Route the emitted action with the source of *this* `.on` declaration — not the internal
            // bridge line — so tracing points at where the bridge was wired.
            return Reaction(mutation: mutation, produce: Reader { _ in
                Effect.just(out.action.review(value), file: file, function: function, line: line)
            })
        })
    }

    /// React to the trigger by **mutating state only** — no action is dispatched — optionally guarded by
    /// `when` (which sits right after the trigger, gating the reaction).
    public func on<T: Sendable, Trigger: Relay.ActionAxis.ExtractsProtocol>(
        _ trigger: Relay.Scope<Action, Trigger, State, Relay.Absurd<State>, Environment, Relay.Absurd<Environment>>,
        when condition: (@Sendable (State) -> Bool)? = nil,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self where Trigger.Global == Action, Trigger.Local == T {
        .combine(self, Behavior { action, context in
            guard let value = trigger.action.preview(action) else { return .doNothing }
            if let condition {
                guard let state = context.stateBefore, condition(state) else { return .doNothing }
            }
            return Reaction(mutation: .mutation(EndoMut { state in reduce(value, &state) }), produce: Reader { _ in .empty })
        })
    }
}
