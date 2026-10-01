// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — fan-out only)

//
// The one general primitive behind the public `liftEach(_:)` Relay-scope host
// (Behavior+RelayScopeCollection.swift); package-internal.
//
// `liftEach` is the 0..n sibling of `liftCollection`: where `liftCollection` routes a global action to ONE element (selected by id), `liftEach`
// runs the per-element behavior on EVERY element at once and folds the results.
//
// Its job is fan-out, across all three axes. Each element's mutation is applied to that element;
// each element's effect is scoped to that element's id (so element A's `.debounce(id: .fetch)` is
// independent of element B's) and its output is re-wrapped by `embed`; and each element's
// `supervise` keeps its own channels, likewise re-embedded and per-element stamped. To handle the
// addressed actions those effects emit, compose this with `liftCollection` on the same
// container — a `supervise` declared on both lifts is deduped by the reconciler (identical ids).
//
//     Behavior.combine(
//         perElement.liftEach(.action(broadcast: AppAction.prism.tickAll, into: AppAction.prism.item).state(\.items)),
//         perElement.liftCollection(.action(\.item).state(\.items))
//     )

extension Behavior {
    /// Primitive — broadcast across an enumerated, addressable container, with a `Lens` container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `Action` to broadcast to every element.
    ///     Returns `nil` for global actions this behavior should ignore (a no-op).
    ///   - embed: Re-wraps an action produced by an element's effect into the global action type,
    ///     addressed at that element's `id`.
    ///   - ids: Enumerates the ids of the elements currently present in the container.
    ///   - element: Addresses one element by id as an `AffineTraversal` inside the container.
    ///   - stateContainer: A `Lens` from the global state to the element container.
    package func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        ids: @escaping @Sendable (Container) -> [ID],
        element: @escaping @Sendable (ID) -> AffineTraversal<Container, State>,
        stateContainer: Lens<GS, Container>
    ) -> Behavior<GA, GS, Environment> {
        Behavior<GA, GS, Environment>(
            handle: { globalAction, context in
                guard let local = action(globalAction), let global = context.stateBefore
                else { return .doNothing }
                let reactions: [Reaction<GA, GS, Environment>] = ids(stateContainer.get(global)).map { id in
                    let traversal = stateContainer.compose(element(id))
                    let scope = AnyHashableSendable(id)
                    let c = self.handle(local, context.compactMap(traversal.preview))
                    return Reaction(
                        mutation: c.mutation.map { traversal.lift($0) },
                        produce: c.produce
                            .map { (eff: Effect<Action>) in eff.map { embed($0, id) }.scopedToElement(scope) }
                            .contramapEnvironment { $0.compactMap(traversal.preview) }
                    )
                }
                return reactions.reduce(.doNothing, Reaction.combine)
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
