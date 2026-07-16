// SPDX-License-Identifier: Apache-2.0

import CoreFP

// The Middleware collection hosts over a ``Relay/Scope``. Structurally identical to the Behavior hosts
// (effects + supervise + environment), except middleware only READS the container (never mutates), which
// the `Keyed` lane's `container` lens satisfies via `get`. Same decorator capabilities and
// `Action.ID == State.ID` coupling; delegates to the tested Middleware collection primitives.

extension Middleware {
    /// Route-to-one collection lift for a middleware — an addressed global action drives the one element
    /// the action lane locates; the middleware observes that element's **unwrapped** state.
    public func liftCollection<A, S, E>(
        _ scope: Relay.Scope<A, S, E>
    ) -> Middleware<A.G, S.G, E.G>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol,
        A.L == Action, S.L == State, E.L == Environment, A.ID == S.ID {
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

    /// Broadcast collection lift for a middleware — observes **every** present element, re-embedding and
    /// per-element stamping each element's emitted effects/channels.
    public func liftEach<A, S, E>(
        _ scope: Relay.Scope<A, S, E>
    ) -> Middleware<A.G, S.G, E.G>
    where
        A: Relay.ActionAxis.BroadcastProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.NarrowsProtocol,
        A.L == Action, S.L == State, E.L == Environment, A.ID == S.ID {
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
