import CoreFP
import DataStructure

// MARK: - liftCollection (primitive — AffineTraversal)
//
// Lifts a per-element `Middleware` into one that operates on a whole collection living inside a
// global state. `Middleware` is read-only on state, so — unlike ``Behavior/liftCollection`` —
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
    /// Primitive — closure-driven extraction plus a `WritableKeyPath` state container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `Action`, an `AffineTraversal`
    ///     selecting the target element inside its container, and the element `id`. Returns
    ///     `nil` for global actions that don't address an element (the middleware is a no-op).
    ///   - embed: Re-wraps an action produced by the element's effect into the global action
    ///     type, addressed at `id`.
    ///   - stateContainer: A `WritableKeyPath` from the global state to the element container
    ///     (only its `get` is used — middleware never mutates).
    /// - Returns: A `Middleware<GA, GS, Environment>` operating on the whole collection.
    public func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> (action: Action, element: AffineTraversal<Container, State>, id: ID)?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Middleware<GA, GS, Environment> {
        liftCollection(action: action, embed: embed, stateContainer: lens(stateContainer))
    }

    /// Primitive — closure-driven extraction plus a `Lens` state container (for composed or
    /// `let`-property containers). Only the lens `get` is used.
    public func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> (action: Action, element: AffineTraversal<Container, State>, id: ID)?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateContainer: Lens<GS, Container>
    ) -> Middleware<GA, GS, Environment> {
        Middleware<GA, GS, Environment> { globalAction, context in
            guard let resolved = action(globalAction) else { return Reader { _ in .empty } }
            let traversal = stateContainer.compose(resolved.element)
            let element = AnyHashableSendable(resolved.id)
            return self.handle(resolved.action, context.compactMap(traversal.preview))
                .map { (eff: Effect<Action>) in
                    eff.map { embed($0, resolved.id) }.scopedToElement(element)
                }
                .contramapEnvironment { $0.compactMap(traversal.preview) }
        }
    }
}

// MARK: - liftCollection (Identifiable element)

extension Middleware where State: Identifiable {
    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// Action extraction and re-embedding go through a single `Prism` into the `ElementAction`
    /// case of the global action. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action prism: Prism<GA, ElementAction<State.ID, Action>>,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action prism: Prism<GA, ElementAction<State.ID, Action>>,
        stateCollection: Lens<GS, C>
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftCollection (custom Hashable identifier)

extension Middleware {
    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field extracted
    /// by `identifier`. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<ID, Action>>,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id, by: identifier), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field.
    /// State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<ID, Action>>,
        stateCollection: Lens<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id, by: identifier), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftCollection (Dictionary key-based)

extension Middleware {
    /// Lifts to a `Dictionary`, locating the entry by its key. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<Key, Action>>,
        stateDictionary: WritableKeyPath<GS, [Key: State]>
    ) -> Middleware<GA, GS, Environment> {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: [Key: State].ix(key: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateDictionary
        )
    }

    /// Lifts to a `Dictionary`, locating the entry by its key. State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<Key, Action>>,
        stateDictionary: Lens<GS, [Key: State]>
    ) -> Middleware<GA, GS, Environment> {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: [Key: State].ix(key: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateDictionary
        )
    }
}
