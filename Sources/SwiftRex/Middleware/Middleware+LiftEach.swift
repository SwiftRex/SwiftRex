// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — fan-out only)

//
// The one general primitive behind the public `liftEach(_:)` Relay-scope host
// (Middleware+RelayScopeCollection.swift); package-internal.
//
// The middleware counterpart of the behavior's `liftEach`. `Middleware` carries no mutation, so the
// broadcast folds the per-element effect readers: each element's effect is scoped to its id and
// re-wrapped by `embed`, and all are merged via `Effect.combine`. It fans out BOTH axes — the
// action-driven effect side (above) and the state-driven `supervise` side (every present element
// keeps its own channels, re-embedded and per-element stamped). Compose with
// `liftCollection` to handle the addressed actions those effects emit; a `supervise`
// declared on both lifts of one container is deduped by the reconciler (identical scoped ids).

extension Middleware {
    /// Primitive — broadcast across an enumerated, addressable container, with a `Lens` container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `Action` to broadcast. `nil` ⇒ no-op.
    ///   - embed: Re-wraps an element effect's output into the global action, addressed at its `id`.
    ///   - ids: Enumerates the ids of the elements currently present in the container.
    ///   - element: Addresses one element by id as an `AffineTraversal` inside the container.
    ///   - stateContainer: A `Lens` from the global state to the container (only `get` is used).
    package func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        ids: @escaping @Sendable (Container) -> [ID],
        element: @escaping @Sendable (ID) -> AffineTraversal<Container, State>,
        stateContainer: Lens<GS, Container>
    ) -> Middleware<GA, GS, Environment> {
        Middleware<GA, GS, Environment>(
            handle: { globalAction, context in
                guard let local = action(globalAction), let global = context.stateBefore
                else { return Reader { _ in .empty } }
                let readers: [Reader<PostReducerContext<GS, Environment>, Effect<GA>>] =
                    ids(stateContainer.get(global)).map { id in
                        let traversal = stateContainer.compose(element(id))
                        let scope = AnyHashableSendable(id)
                        return self.handle(local, context.compactMap(traversal.preview))
                            .map { (eff: Effect<Action>) in eff.map { embed($0, id) }.scopedToElement(scope) }
                            .contramapEnvironment { $0.compactMap(traversal.preview) }
                    }
                return Reader { ctx in readers.map { $0.runReader(ctx) }.reduce(.empty, Effect.combine) }
            },
            // Fan-out the supervise axis the same way the action axis fans out: every present
            // element keeps its own channels, re-embedded and stamped per-element. The reconciler
            // dedups against a `liftCollection` on the same container (identical element-scoped ids).
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (gs: GS) in
                    let container = stateContainer.get(gs)
                    let perElement = ids(container).compactMap { id in
                        element(id).preview(container).map { (element: AnyHashableSendable(id), id: id, keep: inner($0)) }
                    }
                    return Reader { env in
                        perElement.flatMap { p in
                            p.keep.runReader(env).map { $0.mapAction { embed($0, p.id) }.scopedToElement(p.element) }
                        }
                    }
                }
            }
        )
    }
}
