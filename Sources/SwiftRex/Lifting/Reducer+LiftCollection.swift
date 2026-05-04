import CoreFP

// MARK: - liftCollection (CollectionAction — one-sided)

extension Reducer {
    /// Lifts a local reducer using a `CollectionAction` payload carried in the global action.
    ///
    /// The `CollectionAction` encodes the full routing — which container in the global state,
    /// which element within it, and the local action — so no state-side parameter is needed here.
    ///
    /// ```swift
    /// itemReducer.liftCollection(action: \.updateItem)
    ///
    /// // At dispatch:
    /// store.send(.updateItem(CollectionAction(\.items, id: item.id, action: .toggleDone)))
    /// store.send(.updateItem(CollectionAction(\.items, element: [Item].ix(id: item.id), action: .toggleDone)))
    /// ```
    public func liftCollection<GA, GS>(
        action: KeyPath<GA, CollectionAction<GS, StateType, ActionType>?>
    ) -> Reducer<GA, GS> {
        liftCollection(action: { $0[keyPath: action] })
    }

    /// Lifts a local reducer using a closure that produces a `CollectionAction`.
    public func liftCollection<GA, GS>(
        action: @escaping (GA) -> CollectionAction<GS, StateType, ActionType>?
    ) -> Reducer<GA, GS> {
        .reduce { globalAction, globalState in
            guard
                let payload = action(globalAction),
                var localState = payload.elementInRoot.preview(globalState)
            else { return }
            self.reduce(payload.action, &localState)
            globalState = payload.elementInRoot.set(globalState, localState)
        }
    }
}

// MARK: - liftCollection (primitive — AffineTraversal)

extension Reducer {
    /// The primitive two-sided overload: you provide the action extraction closure and a fixed
    /// container key path; the closure returns the local action and an `AffineTraversal` that
    /// selects the element within the container.
    ///
    /// Use the `ix` family from the FP library:
    ///
    /// ```swift
    /// itemReducer.liftCollection(
    ///     action: { ga in
    ///         guard case .updateItem(let id, let sub) = ga else { return nil }
    ///         return (action: sub, element: [Item].ix(id: id))
    ///     },
    ///     stateContainer: \.items
    /// )
    /// ```
    ///
    /// All tuple-based `liftCollection` overloads delegate here.
    public func liftCollection<GA, GS, Container>(
        action: @escaping (GA) -> (action: ActionType, element: AffineTraversal<Container, StateType>)?,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction, globalState in
            guard
                let resolved = action(globalAction),
                var localState = resolved.element.preview(globalState[keyPath: stateContainer])
            else { return }
            self.reduce(resolved.action, &localState)
            globalState[keyPath: stateContainer] = resolved.element.set(globalState[keyPath: stateContainer], localState)
        }
    }
}

// MARK: - liftCollection (Identifiable element)

extension Reducer where StateType: Identifiable {
    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: @escaping (GA) -> (id: StateType.ID, action: ActionType)?,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: C.ix(id: $0.id)) } },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection via a KeyPath, locating the element by its `Identifiable.id`.
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: KeyPath<GA, (id: StateType.ID, action: ActionType)?>,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(action: { $0[keyPath: action] }, stateCollection: stateCollection)
    }
}

// MARK: - liftCollection (custom Hashable identifier)

extension Reducer {
    /// Lifts to a mutable collection, locating the element by a custom `Hashable` identifier.
    public func liftCollection<GA, GS, C: MutableCollection, ID: Hashable>(
        action: @escaping (GA) -> (id: ID, action: ActionType)?,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: KeyPath<StateType, ID>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(
            action: { ga in
                action(ga).map { item in
                    (
                        action: item.action,
                        element: AffineTraversal<C, StateType>(
                            preview: { $0.first(where: { $0[keyPath: identifier] == item.id }) },
                            set: { col, elem in
                                guard let idx = col.firstIndex(where: { $0[keyPath: identifier] == item.id })
                                else { return col }
                                var copy = col
                                copy[idx] = elem
                                return copy
                            }
                        )
                    )
                }
            },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection via a KeyPath, locating the element by a custom `Hashable` identifier.
    public func liftCollection<GA, GS, C: MutableCollection, ID: Hashable>(
        action: KeyPath<GA, (id: ID, action: ActionType)?>,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: KeyPath<StateType, ID>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(action: { $0[keyPath: action] }, stateCollection: stateCollection, identifier: identifier)
    }
}

// MARK: - liftCollection (index-based)

extension Reducer {
    /// Lifts to a mutable collection, locating the element by its index.
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: @escaping (GA) -> (index: C.Index, action: ActionType)?,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: C.ix($0.index)) } },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection via a KeyPath, locating the element by its index.
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: KeyPath<GA, (index: C.Index, action: ActionType)?>,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(action: { $0[keyPath: action] }, stateCollection: stateCollection)
    }
}

// MARK: - liftCollection (Dictionary key-based)

extension Reducer {
    /// Lifts to a `Dictionary`, locating the entry by its key.
    public func liftCollection<GA, GS, Key: Hashable>(
        action: @escaping (GA) -> (key: Key, action: ActionType)?,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: [Key: StateType].ix(key: $0.key)) } },
            stateContainer: stateDictionary
        )
    }

    /// Lifts to a `Dictionary` via a KeyPath, locating the entry by its key.
    public func liftCollection<GA, GS, Key: Hashable>(
        action: KeyPath<GA, (key: Key, action: ActionType)?>,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftCollection(action: { $0[keyPath: action] }, stateDictionary: stateDictionary)
    }
}
