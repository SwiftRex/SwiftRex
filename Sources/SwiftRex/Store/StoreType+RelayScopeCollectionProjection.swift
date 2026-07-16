// SPDX-License-Identifier: Apache-2.0

import CoreFP

// Collection projection over a ``Relay/Scope``. A projection focuses a SINGLE element addressed by `id`
// (a list cell projecting to its own element), so — unlike `liftCollection`, which extracts the id from
// the action — the id is a parameter here. The `Keyed` state lane abstracts the locator, so this one host
// covers Identifiable / custom-id / index / dictionary alike. A store can't be absent, so the projected
// state is `Element?` (the view unwraps with `if let`); the action lane's `review` addresses dispatched
// sub-actions at `id`. Only `review` (embed) + the element read are used — the same capabilities a single
// projection needs, in their id-keyed form.

extension StoreType {
    /// Project this store onto the single element addressed by `id`, through a ``Relay/Scope`` whose action
    /// lane is an ``Relay/ActionAxis/Element`` and state lane a ``Relay/StateAxis/Keyed``. The projected
    /// state is `Element?` (`nil` when the element is absent); dispatched sub-actions are re-embedded
    /// addressed at `id`.
    @MainActor
    public func projection<A, S, E>(
        _ scope: Relay.Scope<A, S, E>,
        element id: A.ID
    ) -> StoreProjection<A.L, S.L?>
    where
        A: Relay.ActionAxis.ElementProtocol,
        S: Relay.StateAxis.KeyedProtocol,
        E: Relay.EnvironmentAxis.Transformation,
        A.G == Action, S.G == State, A.ID == S.ID {
        projection(
            action: { subAction in scope.action.review(id, subAction) },
            state: { global in scope.state.element(id).preview(scope.state.container.get(global)) }
        )
    }
}
