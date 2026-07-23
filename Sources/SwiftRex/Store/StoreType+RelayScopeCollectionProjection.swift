// SPDX-License-Identifier: Apache-2.0

import CoreFP

// Collection projection over a ``Relay/Scope``. A projection focuses a SINGLE element addressed by `id`
// (a list cell projecting to its own element), so — unlike `liftCollection`, which extracts the id from
// the action — the id is a parameter here. The `Keyed` state lane abstracts the locator, so this one host
// covers Identifiable / custom-id / index / dictionary alike. A store can't be absent, so the projected
// state is `Element?` (the view unwraps with `if let`); the action lane's `review` addresses dispatched
// sub-actions at `id`. Only `review` (embed) + the element read are used — the same capabilities a single
// projection needs, in their id-keyed form.
//
// Like the single-element `projection`, two forms: env slot pinned sealed (`Never` global) for inline
// builder chains, and env fully generic for a declared collection scope shared with the lift hosts.

extension StoreType {
    /// Project this store onto the single element addressed by `id`, through a ``Relay/Scope`` whose action
    /// lane is an ``Relay/ActionAxis/Element`` and state lane a ``Relay/StateAxis/Keyed``. The projected
    /// state is `Element?` (`nil` when the element is absent); dispatched sub-actions are re-embedded
    /// addressed at `id`.
    @MainActor
    public func projection<A, S>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        element id: A.ID
    ) -> StoreProjection<A.Local, S.Local?>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        A.Global == Action, S.Global == State, A.ID == S.ID {
        elementProjection(scope, id: id)
    }

    /// Element projection through a **declared** collection scope — the environment axis is generic and
    /// ignored, so the scope shared with the `liftCollection`/`liftEach` hosts serves cells too.
    @MainActor
    public func projection<A, S, GE, E>(
        _ scope: Relay.Scope<Action, A, State, S, GE, E>,
        element id: A.ID
    ) -> StoreProjection<A.Local, S.Local?>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Global == Action, S.Global == State, A.ID == S.ID {
        elementProjection(scope, id: id)
    }

    @MainActor
    private func elementProjection<A, S, GE, E>(
        _ scope: Relay.Scope<Action, A, State, S, GE, E>,
        id: A.ID
    ) -> StoreProjection<A.Local, S.Local?>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Strategy,
        A.Global == Action, S.Global == State, A.ID == S.ID {
        projection(
            action: { subAction in scope.action.review(id, subAction) },
            state: { global in scope.state.element(id).preview(scope.state.container.get(global)) }
        )
    }
}
