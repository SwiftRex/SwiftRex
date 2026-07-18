// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - Cross-feature routing (`.on`) — axis-separated
//
// One shape collapses the routing family: a **trigger** (`.action(…)` — an `Extracts` that previews the
// payload from the action) and, optionally, a **dispatch** (`.action(…)` embed or a transform closure) and
// a **reduce** (co-located state mutation), each guarded by an optional `when`. State is never touched
// unless the trigger matches — and, when there is no `reduce`, the mutation is `.unchanged`, so a
// routing-only `.on` never copies state.
//
//     .on(.action(\.didLoad), dispatch: .action(\.renderItems))
//     .on(.action(\.didLoad), dispatch: { .renderItems($0) }, reduce: { items, s in s.items = items })
//     .on(.action(\.retry), reduce: { _, s in s.attempts += 1 }, when: { $0.attempts < 3 })

extension Behavior {
    // The routing core: extract the trigger, optionally guard and mutate, then emit `out(value)`.
    // Public entry points build `out` from an `.action(…)` embed — closures are never passed bare.
    private func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        dispatch out: @escaping @Sendable (T) -> Action,
        reduce: (@Sendable (T, inout State) -> Void)? = nil,
        when condition: (@Sendable (State) -> Bool)? = nil
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = trigger.preview(action) else { return .doNothing }
            if let condition {
                guard let state = context.stateBefore, condition(state) else { return .doNothing }
            }
            let mutation: ReducerOutcome<State> = reduce.map { reduce in
                .mutation(EndoMut { state in reduce(value, &state) })
            } ?? .unchanged
            return Reaction(mutation: mutation, produce: Reader { _ in Effect.just(out(value)) })
        })
    }

    /// Route the trigger's payload by **embedding** it into an outbound action (`.action(…)`), optionally
    /// mutating state and guarding on a predicate.
    public func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        dispatch out: Relay.ActionAxis.Embeds<Action, T>,
        reduce: (@Sendable (T, inout State) -> Void)? = nil,
        when condition: (@Sendable (State) -> Bool)? = nil
    ) -> Self {
        on(trigger, dispatch: out.review, reduce: reduce, when: condition)
    }

    /// React to the trigger by **mutating state only** — no action is dispatched — optionally guarded.
    public func on<T: Sendable>(
        _ trigger: Relay.ActionAxis.Extracts<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void,
        when condition: (@Sendable (State) -> Bool)? = nil
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = trigger.preview(action) else { return .doNothing }
            if let condition {
                guard let state = context.stateBefore, condition(state) else { return .doNothing }
            }
            return Reaction(mutation: .mutation(EndoMut { state in reduce(value, &state) }), produce: Reader { _ in .empty })
        })
    }
}
