import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — fan-out only)
//
// `liftEach` is the 0..n sibling of ``Behavior/liftCollection(action:embed:stateContainer:)-``:
// where `liftCollection` routes a global action to ONE element (selected by id), `liftEach`
// runs the per-element behavior on EVERY element at once and folds the results.
//
// It has ONE job — fan-out. Each element's mutation is applied to that element; each element's
// effect is scoped to that element's id (so element A's `.debounce(id: .fetch)` is independent
// of element B's) and its output is re-wrapped by `embed`. To handle the addressed actions those
// effects emit, compose this with ``Behavior/liftCollection`` on the same container.
//
//     Behavior.combine(
//         perElement.liftEach(action: …tickAll…, embed: …ElementAction…, stateCollection: \.items),
//         perElement.liftCollection(action: …ElementAction prism…, stateCollection: \.items)
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
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        ids: @escaping @Sendable (Container) -> [ID],
        element: @escaping @Sendable (ID) -> AffineTraversal<Container, State>,
        stateContainer: Lens<GS, Container>
    ) -> Behavior<GA, GS, Environment> {
        Behavior<GA, GS, Environment> { globalAction, context in
            guard let local = action(globalAction), let global = context.stateBefore
            else { return .doNothing }
            let consequences: [Consequence<GS, Environment, GA>] = ids(stateContainer.get(global)).map { id in
                let traversal = stateContainer.compose(element(id))
                let scope = AnyHashableSendable(id)
                let c = self.handle(local, context.compactMap(traversal.preview))
                return Consequence(
                    mutation: c.mutation.map { traversal.lift($0) },
                    effect: c.effect
                        .map { (eff: Effect<Action>) in eff.map { embed($0, id) }.scopedToElement(scope) }
                        .contramapEnvironment { $0.compactMap(traversal.preview) }
                )
            }
            return consequences.reduce(.doNothing, Consequence.combine)
        }
    }

    /// Primitive — broadcast across an enumerated, addressable container, with a `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        ids: @escaping @Sendable (Container) -> [ID],
        element: @escaping @Sendable (ID) -> AffineTraversal<Container, State>,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Behavior<GA, GS, Environment> {
        liftEach(action: action, embed: embed, ids: ids, element: element, stateContainer: lens(stateContainer))
    }
}

// MARK: - liftEach (Identifiable element)

extension Behavior where State: Identifiable {
    /// Broadcasts to every element of a mutable collection, keyed by `Identifiable.id`.
    /// State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, State.ID) -> GA,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftEach(
            action: action,
            embed: embed,
            ids: { $0.map(\.id) },
            element: { C.ix(id: $0) },
            stateContainer: lens(stateCollection)
        )
    }

    /// Broadcasts to every element of a mutable collection, keyed by `Identifiable.id`.
    /// State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, State.ID) -> GA,
        stateCollection: Lens<GS, C>
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
        liftEach(
            action: action,
            embed: embed,
            ids: { $0.map(\.id) },
            element: { C.ix(id: $0) },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftEach (custom Hashable identifier)

extension Behavior {
    /// Broadcasts to every element of a mutable collection, keyed by a custom `Hashable` field.
    /// State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable {
        liftEach(
            action: action,
            embed: embed,
            ids: { $0.map(identifier) },
            element: { C.ix(id: $0, by: identifier) },
            stateContainer: lens(stateCollection)
        )
    }

    /// Broadcasts to every element of a mutable collection, keyed by a custom `Hashable` field.
    /// State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateCollection: Lens<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Behavior<GA, GS, Environment> where C.Element == State, C.Index: Sendable {
        liftEach(
            action: action,
            embed: embed,
            ids: { $0.map(identifier) },
            element: { C.ix(id: $0, by: identifier) },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftEach (Dictionary key-based)

extension Behavior {
    /// Broadcasts to every value of a dictionary, keyed by its key. State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, Key) -> GA,
        stateDictionary: WritableKeyPath<GS, [Key: State]>
    ) -> Behavior<GA, GS, Environment> {
        liftEach(
            action: action,
            embed: embed,
            ids: { Array($0.keys) },
            element: { [Key: State].ix(key: $0) },
            stateContainer: lens(stateDictionary)
        )
    }

    /// Broadcasts to every value of a dictionary, keyed by its key. State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, Key) -> GA,
        stateDictionary: Lens<GS, [Key: State]>
    ) -> Behavior<GA, GS, Environment> {
        liftEach(
            action: action,
            embed: embed,
            ids: { Array($0.keys) },
            element: { [Key: State].ix(key: $0) },
            stateContainer: stateDictionary
        )
    }
}

// MARK: - liftEach (general container — IndexedTraversal)

extension Behavior {
    /// Broadcasts across every focus of an `IndexedTraversal` (any container, not just
    /// collections); each focus's index is its scoping id. State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        each: IndexedTraversal<Container, ID, State>,
        stateContainer: Lens<GS, Container>
    ) -> Behavior<GA, GS, Environment> {
        liftEach(
            action: action,
            embed: embed,
            ids: { each.getAll($0).map(\.0) },
            element: { each.element($0) },
            stateContainer: stateContainer
        )
    }

    /// Broadcasts across every focus of an `IndexedTraversal`. State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        each: IndexedTraversal<Container, ID, State>,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Behavior<GA, GS, Environment> {
        liftEach(action: action, embed: embed, each: each, stateContainer: lens(stateContainer))
    }
}
