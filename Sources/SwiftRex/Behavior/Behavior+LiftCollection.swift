import CoreFP
import DataStructure

// MARK: - liftCollection (primitive — AffineTraversal)
//
// Lifts a per-element `Behavior` into one that operates on a whole collection living inside a
// global state. Unlike ``Reducer/liftCollection(action:stateContainer:)-``, a `Behavior` also
// carries effects, so the primitive needs two extra pieces beyond the state traversal:
//
//   • `embed` — re-wraps an action emitted by an element's effect back into the global action
//     type, so it can re-enter the ``Store`` addressed at the same element.
//   • the element `id` — used to scope each element's effect-scheduling ids (see below).
//
// ## Per-element effect-scheduling isolation
//
// Every lifted element shares the same `Behavior`, so two elements would otherwise collide on
// any ``EffectScheduling`` id (`.debounce(id: .fetch)` from element A would cancel element B's).
// `liftCollection` rewrites each element's scheduling ids to `ElementScopedID(element: id, …)`,
// so element A's `.fetch` is independent of element B's `.fetch`.
//
// The user keeps owning the *inner* id: if two different features both use a `"fetch"` string,
// that cross-feature collision is theirs to prevent (use distinct id enums), exactly as for
// un-lifted effects. The scope only adds the element axis.

extension Behavior {
    /// Primitive — closure-driven extraction plus a `WritableKeyPath` state container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `Action`, an `AffineTraversal`
    ///     selecting the target element inside its container, and the element `id`. Returns
    ///     `nil` for global actions that don't address an element (the behavior is a no-op).
    ///   - embed: Re-wraps an action produced by the element's effect into the global action
    ///     type, addressed at `id`.
    ///   - stateContainer: A `WritableKeyPath` from the global state to the element container.
    ///   - elements: Optional enumerator of the container's `(id, state)` pairs, used to fan the
    ///     per-element `supervise` axis across the collection (each element's channels re-embedded
    ///     and stamped per element). `nil` (the default) supervises nothing.
    /// - Returns: A `Behavior<GA, GS, Environment>` operating on the whole collection.
    public func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> (action: Action, element: AffineTraversal<Container, State>, id: ID)?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateContainer: WritableKeyPath<GS, Container>,
        elements: (@Sendable (Container) -> [(id: ID, state: State)])? = nil
    ) -> Behavior<GA, GS, Environment> {
        liftCollection(action: action, embed: embed, stateContainer: lens(stateContainer), elements: elements)
    }

    /// Primitive — closure-driven extraction plus a `Lens` state container (for composed or
    /// `let`-property containers).
    public func liftCollection<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> (action: Action, element: AffineTraversal<Container, State>, id: ID)?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateContainer: Lens<GS, Container>,
        elements: (@Sendable (Container) -> [(id: ID, state: State)])? = nil
    ) -> Behavior<GA, GS, Environment> {
        Behavior<GA, GS, Environment>(
            handle: { globalAction, context in
                guard let resolved = action(globalAction) else { return .doNothing }
                let traversal = stateContainer.compose(resolved.element)
                let element = AnyHashableSendable(resolved.id)
                let c = self.handle(resolved.action, context.compactMap(traversal.preview))
                return Consequence(
                    mutation: c.mutation.map { traversal.lift($0) },
                    effect: c.effect
                        .map { (eff: Effect<Action>) in
                            eff.map { embed($0, resolved.id) }.scopedToElement(element)
                        }
                        .contramapEnvironment { $0.compactMap(traversal.preview) }
                )
            },
            // For each element, run its supervisor, re-embed the channel actions, and stamp the
            // channel ids per-element (so element A's `"socket"` ≠ element B's `"socket"`).
            supervisor: self.supervisor.map { inner in
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

// MARK: - liftCollection (Identifiable element)

extension Behavior where State: Identifiable {
    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// Action extraction and re-embedding go through a single `Prism` into the `ElementAction`
    /// case of the global action. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action prism: Prism<GA, ElementAction<State.ID, Action>>,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection,
            elements: { container in container.map { (id: $0.id, state: $0) } }
        )
    }

    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action prism: Prism<GA, ElementAction<State.ID, Action>>,
        stateCollection: Lens<GS, C>
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection,
            elements: { container in container.map { (id: $0.id, state: $0) } }
        )
    }
}

// MARK: - liftCollection (custom Hashable identifier)

extension Behavior {
    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field extracted
    /// by `identifier`. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<ID, Action>>,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id, by: identifier), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection,
            elements: { container in container.map { (id: identifier($0), state: $0) } }
        )
    }

    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field.
    /// State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<ID, Action>>,
        stateCollection: Lens<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: C.ix(id: $0.id, by: identifier), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateCollection,
            elements: { container in container.map { (id: identifier($0), state: $0) } }
        )
    }
}

// MARK: - liftCollection (Dictionary key-based)

extension Behavior {
    /// Lifts to a `Dictionary`, locating the entry by its key. State container via `WritableKeyPath`.
    public func liftCollection<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<Key, Action>>,
        stateDictionary: WritableKeyPath<GS, [Key: State]>
    ) -> Behavior<GA, GS, Environment> {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: [Key: State].ix(key: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateDictionary,
            elements: { dict in dict.map { (id: $0.key, state: $0.value) } }
        )
    }

    /// Lifts to a `Dictionary`, locating the entry by its key. State container via `Lens`.
    public func liftCollection<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action prism: Prism<GA, ElementAction<Key, Action>>,
        stateDictionary: Lens<GS, [Key: State]>
    ) -> Behavior<GA, GS, Environment> {
        liftCollection(
            action: { ga in prism.preview(ga).map { (action: $0.action, element: [Key: State].ix(key: $0.id), id: $0.id) } },
            embed: { action, id in prism.review(ElementAction(id, action: action)) },
            stateContainer: stateDictionary,
            elements: { dict in dict.map { (id: $0.key, state: $0.value) } }
        )
    }
}
