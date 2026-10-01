// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftCollection (primitive — AffineTraversal)

//
// The one general primitive behind the public `liftCollection(_:)` Relay-scope hosts
// (Reducer+RelayScopeCollection.swift); package-internal. A closure returns the local action and an
// `AffineTraversal` selecting the exact element within its container. Users lift with
// `todoReducer.liftCollection(.action(\.todo).state(\.todos))`.

extension Reducer {
    /// Primitive — closure-driven extraction plus a `Lens` state container.
    package func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> (action: ActionType, element: AffineTraversal<Container, StateType>)?,
        stateContainer: Lens<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let resolved = action(globalAction) else { return .identity }
            return stateContainer.compose(resolved.element).lift(self.reduce(resolved.action))
        }
    }
}
