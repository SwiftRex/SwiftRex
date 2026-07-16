// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The Reducer collection hosts over a ``Relay/Scope``. Reducers carry no environment and no effects, so
// these are the simplest of the collection hosts: the action lane's `review` (id-embed) is unused (there
// are no emitted effects to re-address), and the environment axis is ignored. They demand the same
// decorator capabilities as the Behavior hosts (`ElementProtocol`/`BroadcastProtocol` + `KeyedProtocol`,
// `Action.ID == State.ID`), delegating to the tested Reducer collection primitives.

extension Reducer {
    /// Route-to-one collection lift: an addressed global action drives the one element the action lane
    /// locates. The lifted reducer sees the **unwrapped** element.
    public func liftCollection<A, S, E>(
        _ scope: Relay.Scope<A, S, E>
    ) -> Reducer<A.G, S.G>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Transformation,
        A.L == ActionType, S.L == StateType, A.ID == S.ID {
        liftCollection(
            action: { ga in scope.action.preview(ga).map { (action: $0.action, element: scope.state.element($0.id)) } },
            stateContainer: scope.state.container
        )
    }

    /// Broadcast collection lift: a global action drives **every** present element.
    public func liftEach<A, S, E>(
        _ scope: Relay.Scope<A, S, E>
    ) -> Reducer<A.G, S.G>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Transformation,
        A.L == ActionType, S.L == StateType, A.ID == S.ID {
        liftEach(
            action: scope.action.preview,
            each: scope.state.eachTraversal,
            stateContainer: scope.state.container
        )
    }
}
