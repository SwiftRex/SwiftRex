// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftCollection (primitive — AffineTraversal)

//
// The one general primitive behind the public `liftCollection(_:)` Relay-scope host
// (Middleware+RelayScopeCollection.swift); package-internal.
//
// Lifts a per-element `Middleware` into one that operates on a whole collection living inside a
// global state. `Middleware` is read-only on state, so — unlike the behavior's —
// there is no mutation to lift; only the effect side is transformed. Two extra pieces beyond the
// state traversal are still needed:
//
//   • `embed` — re-wraps an action emitted by an element's effect back into the global action
//     type, so it can re-enter the ``Store`` addressed at the same element.
//   • the element `id` — used to scope each element's effect-scheduling ids.
//
// ## Per-element effect-scheduling isolation
//
// Every lifted element shares the same `Middleware`, so two elements would otherwise collide on
// any ``EffectScheduling`` id. `liftCollection` rewrites each element's scheduling ids to
// `ElementScopedID(element: id, …)`, so element A's `.debounce(id: .fetch)` is independent of
// element B's. The user keeps owning the inner id; cross-feature collisions remain theirs to
// prevent (use distinct id enums), exactly as for un-lifted effects.

extension Middleware {
    /// Primitive — closure-driven extraction plus a `Lens` state container (only its `get` is used —
    /// middleware never mutates).
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `Action`, an `AffineTraversal`
    ///     selecting the target element inside its container, and the element `id`. Returns
    ///     `nil` for global actions that don't address an element (the middleware is a no-op).
    ///   - embed: Re-wraps an action produced by the element's effect into the global action
    ///     type, addressed at `id`.
    ///   - stateContainer: A `Lens` from the global state to the element container.
    ///   - elements: Optional enumerator of the container's `(id, state)` pairs, used to fan the
    ///     per-element `supervise` axis across the collection. `nil` (the default) supervises nothing.
    package func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> (action: Action, element: AffineTraversal<Container, State>, id: ID)?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateContainer: Lens<GS, Container>,
        elements: (@Sendable (Container) -> [(id: ID, state: State)])? = nil
    ) -> Middleware<GA, GS, Environment> {
        Middleware<GA, GS, Environment>(
            handle: { globalAction, context in
                guard let resolved = action(globalAction) else { return Reader { _ in .empty } }
                let traversal = stateContainer.compose(resolved.element)
                let element = AnyHashableSendable(resolved.id)
                return self.handle(resolved.action, context.compactMap(traversal.preview))
                    .map { (eff: Effect<Action>) in
                        eff.map { embed($0, resolved.id) }.scopedToElement(element)
                    }
                    .contramapEnvironment { $0.compactMap(traversal.preview) }
            },
            // For each element, run its supervisor, re-embed the channel actions, and stamp the
            // channel ids per-element (so element A's `"socket"` ≠ element B's `"socket"`).
            supervisor: supervisor.map { inner in
                { @MainActor @Sendable (gs: GS) in
                    guard let elements else { return Reader { _ in [] } }
                    let perElement = elements(stateContainer.get(gs)).map { pair in
                        (element: AnyHashableSendable(pair.id), id: pair.id, keep: inner(pair.state))
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
