// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The Reducer collection hosts over a ``Relay/Scope``. Reducers carry no environment and no effects, so
// these are the simplest of the collection hosts: the action lane's `review` (id-embed) is unused (there
// are no emitted effects to re-address), and the environment axis is ignored. They demand the same
// decorator capabilities as the Behavior hosts (`ElementProtocol`/`BroadcastProtocol` + `KeyedProtocol`,
// `Action.ID == State.ID`), delegating to the tested Reducer collection primitives.
//
// Like `Reducer.lift`, each host comes in two forms: env slot pinned sealed (`Never` global) so an
// inline builder chain leaves nothing free, and env fully generic so a declared duplex collection scope
// (shared with the Behavior/Middleware hosts) also lifts the reducer.

extension Reducer {
    /// Route-to-one collection lift: an addressed global action drives the one element the action lane
    /// locates. The lifted reducer sees the **unwrapped** element.
    public func liftCollection<A, S>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, Never, Relay.Absurd<Never>>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftedCollection(through: scope)
    }

    /// Route-to-one collection lift through a **declared** scope — the environment axis is generic and
    /// ignored, so the collection scope shared with the Behavior/Middleware hosts lifts the reducer too.
    public func liftCollection<A, S, GE, E>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftedCollection(through: scope)
    }

    /// Broadcast collection lift: a global action drives **every** present element.
    public func liftEach<A, S>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, Never, Relay.Absurd<Never>>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftedEach(through: scope)
    }

    /// Broadcast collection lift through a **declared** scope — env generic and ignored.
    public func liftEach<A, S, GE, E>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftedEach(through: scope)
    }

    private func liftedCollection<A, S, GE, E>(
        through scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftCollection(
            action: { ga in scope.action.preview(ga).map { (action: $0.action, element: scope.state.element($0.id)) } },
            stateContainer: scope.state.container
        )
    }

    private func liftedEach<A, S, GE, E>(
        through scope: Relay.Scope<A.Global, A, S.Global, S, GE, E>
    ) -> Reducer<A.Global, S.Global>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Local == ActionType, S.Local == StateType, A.ID == S.ID {
        liftEach(
            action: scope.action.preview,
            each: scope.state.eachTraversal,
            stateContainer: scope.state.container
        )
    }
}
