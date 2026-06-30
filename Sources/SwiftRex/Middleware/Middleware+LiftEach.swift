import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — fan-out only)
//
// The middleware counterpart of ``Behavior/liftEach``. `Middleware` carries no mutation, so the
// broadcast folds the per-element effect readers: each element's effect is scoped to its id and
// re-wrapped by `embed`, and all are merged via `Effect.combine`. It fans out BOTH axes — the
// action-driven effect side (above) and the state-driven `supervise` side (every present element
// keeps its own channels, re-embedded and per-element stamped). Compose with
// ``Middleware/liftCollection`` to handle the addressed actions those effects emit; a `supervise`
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
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
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
            supervisor: self.supervisor.map { inner in
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

    /// Primitive — broadcast across an enumerated, addressable container, with a `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        ids: @escaping @Sendable (Container) -> [ID],
        element: @escaping @Sendable (ID) -> AffineTraversal<Container, State>,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Middleware<GA, GS, Environment> {
        liftEach(action: action, embed: embed, ids: ids, element: element, stateContainer: lens(stateContainer))
    }
}

// MARK: - liftEach (Identifiable element)

extension Middleware where State: Identifiable {
    /// Broadcasts to every element of a mutable collection, keyed by `Identifiable.id`.
    /// State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, State.ID) -> GA,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
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
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable, State.ID: Sendable {
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

extension Middleware {
    /// Broadcasts to every element of a mutable collection, keyed by a custom `Hashable` field.
    /// State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (State) -> ID
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable {
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
    ) -> Middleware<GA, GS, Environment> where C.Element == State, C.Index: Sendable {
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

extension Middleware {
    /// Broadcasts to every value of a dictionary, keyed by its key. State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, Key) -> GA,
        stateDictionary: WritableKeyPath<GS, [Key: State]>
    ) -> Middleware<GA, GS, Environment> {
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
    ) -> Middleware<GA, GS, Environment> {
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

extension Middleware {
    /// Broadcasts across every focus of an `IndexedTraversal` (any container); each focus's
    /// index is its scoping id. State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> Action?,
        embed: @escaping @Sendable (Action, ID) -> GA,
        each: IndexedTraversal<Container, ID, State>,
        stateContainer: Lens<GS, Container>
    ) -> Middleware<GA, GS, Environment> {
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
    ) -> Middleware<GA, GS, Environment> {
        liftEach(action: action, embed: embed, each: each, stateContainer: lens(stateContainer))
    }
}
