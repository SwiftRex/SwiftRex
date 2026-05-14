import CoreFP
import DataStructure

// MARK: - liftCollection (primitive — AffineTraversal)
//
// The primitive overload: provide a closure that returns the local action and an
// `AffineTraversal` selecting the exact element within its container.
//
// Use the `ix` family from the FP library to build the traversal:
//
//   todoReducer.liftCollection(
//       action: { (ea: ElementAction<UUID, TodoAction>?) in
//           ea.map { (action: $0.action, element: [Todo].ix(id: $0.id)) }
//       },
//       stateContainer: \.todos              // WritableKeyPath
//   )
//
// All `ElementAction`-based `liftCollection` overloads delegate here.

extension Reducer {
    /// Primitive — `WritableKeyPath` for state container.
    public func liftCollection<GA, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> (action: ActionType, element: AffineTraversal<Container, StateType>)?,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let resolved = action(globalAction) else { return .identity }
            return lens(stateContainer).compose(resolved.element).lift(self.reduce(resolved.action))
        }
    }

    /// Primitive — `Lens` for state container (for composed or `let`-property containers).
    public func liftCollection<GA, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> (action: ActionType, element: AffineTraversal<Container, StateType>)?,
        stateContainer: Lens<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let resolved = action(globalAction) else { return .identity }
            return stateContainer.compose(resolved.element).lift(self.reduce(resolved.action))
        }
    }
}

// MARK: - liftCollection (Identifiable element)

extension Reducer where StateType: Identifiable {
    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// State container via `WritableKeyPath`.
    public func liftCollection<GA, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<StateType.ID, ActionType>?,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType, C.Index: Sendable, StateType.ID: Sendable, StateType: Sendable {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: C.ix(id: $0.id)) } },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    /// State container via `Lens`.
    public func liftCollection<GA, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<StateType.ID, ActionType>?,
        stateCollection: Lens<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType, C.Index: Sendable, StateType.ID: Sendable, StateType: Sendable {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: C.ix(id: $0.id)) } },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftCollection (custom Hashable identifier)

extension Reducer {
    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field.
    /// The `identifier` closure extracts the ID from an element.
    /// State container via `WritableKeyPath`.
    public func liftCollection<GA, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<ID, ActionType>?,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (StateType) -> ID
    ) -> Reducer<GA, GS> where C.Element == StateType, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in action(ga).map { ea in (action: ea.action, element: C.ix(id: ea.id, by: identifier)) } },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field.
    /// State container via `Lens`.
    public func liftCollection<GA, GS: Sendable, C: MutableCollection & Sendable, ID: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<ID, ActionType>?,
        stateCollection: Lens<GS, C>,
        identifier: @escaping @Sendable (StateType) -> ID
    ) -> Reducer<GA, GS> where C.Element == StateType, C.Element: Sendable, C.Index: Sendable {
        liftCollection(
            action: { ga in action(ga).map { ea in (action: ea.action, element: C.ix(id: ea.id, by: identifier)) } },
            stateContainer: stateCollection
        )
    }
}

// MARK: - liftCollection (Dictionary key-based)

extension Reducer {
    /// Lifts to a `Dictionary`, locating the entry by its key.
    /// State container via `WritableKeyPath`.
    public func liftCollection<GA, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<Key, ActionType>?,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> where StateType: Sendable {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: [Key: StateType].ix(key: $0.id)) } },
            stateContainer: stateDictionary
        )
    }

    /// Lifts to a `Dictionary`, locating the entry by its key.
    /// State container via `Lens`.
    public func liftCollection<GA, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ElementAction<Key, ActionType>?,
        stateDictionary: Lens<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> where StateType: Sendable {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: [Key: StateType].ix(key: $0.id)) } },
            stateContainer: stateDictionary
        )
    }
}
