// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The collection hosts over a ``Relay/Scope``. They are DISTINCT hosts from `Behavior.lift`: they demand
// the decorator capabilities (``Relay/ActionAxis/ElementProtocol`` / ``Relay/ActionAxis/BroadcastProtocol``
// + ``Relay/StateAxis/KeyedProtocol``), which `lift` never offers. The `Action.ID == State.ID` clause is
// the cross-axis coupling — the id the action extracts is the id the state focuses. Each host translates
// the scope's witnesses into the existing tested primitives (which already stamp per-element effect ids and
// fan the supervise axis), then narrows the environment.

extension Behavior {
    /// Route-to-one collection lift: an addressed global action drives **one** element, located by the
    /// id the action lane extracts. The lifted behavior sees the **unwrapped** element.
    public func liftCollection<A, S, E>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, E.Global, E>
    ) -> Behavior<A.Global, S.Global, E.Global>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol,
        A.Local == Action, S.Local == State, E.Local == Environment, A.ID == S.ID {
        liftCollection(
            action: { ga in
                scope.action.preview(ga).map { hit in
                    (action: hit.action, element: scope.state.element(hit.id), id: hit.id)
                }
            },
            embed: { action, id in scope.action.review(id, action) },
            stateContainer: scope.state.container,
            elements: { container in
                scope.state.ids(container).compactMap { id in
                    scope.state.element(id).preview(container).map { (id: id, state: $0) }
                }
            }
        )
        .liftEnvironment(scope.environment.narrow)
    }
}

extension Behavior {
    /// Broadcast collection lift: a global action is delivered to **every** present element, and each
    /// element's emitted actions/effects are re-embedded and stamped at its own id.
    public func liftEach<A, S, E>(
        _ scope: Relay.Scope<A.Global, A, S.Global, S, E.Global, E>
    ) -> Behavior<A.Global, S.Global, E.Global>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol,
        A.Local == Action, S.Local == State, E.Local == Environment, A.ID == S.ID {
        liftEach(
            action: scope.action.preview,
            embed: { action, id in scope.action.review(id, action) },
            ids: scope.state.ids,
            element: scope.state.element,
            stateContainer: scope.state.container
        )
        .liftEnvironment(scope.environment.narrow)
    }
}
