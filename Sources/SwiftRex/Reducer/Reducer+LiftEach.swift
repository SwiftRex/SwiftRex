// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — Traversal)

//
// The one general primitive behind the public `liftEach(_:)` Relay-scope hosts
// (Reducer+RelayScopeCollection.swift); package-internal.
//
// `liftEach` is the 0..n sibling of `liftCollection`: where
// `liftCollection` routes a global action to ONE element (selected by id), `liftEach` applies the
// resolved local action to EVERY focus of a `Traversal` at once.
//
// A `Reducer` carries no effects, so the broadcast is just `Traversal.lift` of the per-element
// reduce: each focus gets the same `EndoMut<StateType>` applied to its own state, zero-copy on
// the array buffer. (Per-element effect-id scoping only matters for `Behavior`/`Middleware`.)

extension Reducer {
    /// Primitive — broadcast across a `Traversal`, with a `Lens` state container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `ActionType` to broadcast. Returns
    ///     `nil` for global actions this reducer should ignore (a no-op).
    ///   - each: The traversal selecting every target focus inside its container.
    ///   - stateContainer: A `Lens` from the global state to the container.
    package func liftEach<GA: Sendable, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        each: Traversal<Container, StateType>,
        stateContainer: Lens<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let local = action(globalAction) else { return .identity }
            return stateContainer.compose(each).lift(self.reduce(local))
        }
    }
}
