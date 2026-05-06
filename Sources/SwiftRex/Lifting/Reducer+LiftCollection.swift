import CoreFP

// MARK: - liftCollection (primitive — AffineTraversal)

extension Reducer {
    /// The primitive overload: provide a closure that returns the local action and an
    /// `AffineTraversal` selecting the exact element within its container.
    ///
    /// Use the `ix` family from the FP library to build the traversal:
    ///
    /// ```swift
    /// todoReducer.liftCollection(
    ///     action: { (ea: ElementAction<UUID, TodoAction>?) in
    ///         ea.map { (action: $0.action, element: [Todo].ix(id: $0.id)) }
    ///     },
    ///     stateContainer: \AppState.todos
    /// )
    /// ```
    ///
    /// All `ElementAction`-based `liftCollection` overloads delegate here.
    public func liftCollection<GA, GS, Container>(
        action: @escaping (GA) -> (action: ActionType, element: AffineTraversal<Container, StateType>)?,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let resolved = action(globalAction) else { return .identity }
            return EndoMut { globalState in
                guard var localState = resolved.element.preview(globalState[keyPath: stateContainer]) else { return }
                self.reduce(resolved.action).runEndoMut(&localState)
                globalState[keyPath: stateContainer] = resolved.element.set(globalState[keyPath: stateContainer], localState)
            }
        }
    }
}

// MARK: - liftCollection (Identifiable element)

extension Reducer where StateType: Identifiable {
    /// Lifts to a mutable collection, locating the element by its `Identifiable.id`.
    ///
    /// ```swift
    /// todoReducer.liftCollection(
    ///     action: { (ea: ElementAction<UUID, TodoAction>?) in ea },
    ///     stateCollection: \AppState.todos
    /// )
    /// ```
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: @escaping (GA) -> ElementAction<StateType.ID, ActionType>?,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: C.ix(id: $0.id)) } },
            stateContainer: stateCollection
        )
    }

    /// Lifts to a mutable collection via a KeyPath, locating the element by its `Identifiable.id`.
    ///
    /// ```swift
    /// // AppAction has: var updateTodo: ElementAction<UUID, TodoAction>?
    /// todoReducer.liftCollection(action: \AppAction.updateTodo, stateCollection: \AppState.todos)
    /// ```
    public func liftCollection<GA, GS, C: MutableCollection>(
        action: KeyPath<GA, ElementAction<StateType.ID, ActionType>?>,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(action: { $0[keyPath: action] }, stateCollection: stateCollection)
    }
}

// MARK: - liftCollection (custom Hashable identifier)

extension Reducer {
    /// Lifts to a mutable collection, locating the element by a custom `Hashable` field.
    ///
    /// ```swift
    /// projectReducer.liftCollection(
    ///     action: { (ea: ElementAction<String, ProjectAction>?) in ea },
    ///     stateCollection: \AppState.projects,
    ///     identifier: \Project.slug
    /// )
    /// ```
    public func liftCollection<GA, GS, C: MutableCollection, ID: Hashable>(
        action: @escaping (GA) -> ElementAction<ID, ActionType>?,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: KeyPath<StateType, ID>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(
            action: { ga in
                action(ga).map { ea in
                    (
                        action: ea.action,
                        element: AffineTraversal<C, StateType>(
                            preview: { $0.first(where: { $0[keyPath: identifier] == ea.id }) },
                            set: { col, elem in
                                guard let idx = col.firstIndex(where: { $0[keyPath: identifier] == ea.id })
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

    /// Lifts to a mutable collection via a KeyPath, locating the element by a custom `Hashable` field.
    ///
    /// ```swift
    /// // AppAction has: var updateProject: ElementAction<String, ProjectAction>?
    /// projectReducer.liftCollection(
    ///     action: \AppAction.updateProject,
    ///     stateCollection: \AppState.projects,
    ///     identifier: \Project.slug
    /// )
    /// ```
    public func liftCollection<GA, GS, C: MutableCollection, ID: Hashable>(
        action: KeyPath<GA, ElementAction<ID, ActionType>?>,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: KeyPath<StateType, ID>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftCollection(action: { $0[keyPath: action] }, stateCollection: stateCollection, identifier: identifier)
    }
}

// MARK: - liftCollection (Dictionary key-based)

extension Reducer {
    /// Lifts to a `Dictionary`, locating the entry by its key.
    ///
    /// ```swift
    /// configReducer.liftCollection(
    ///     action: { (ea: ElementAction<String, ConfigAction>?) in ea },
    ///     stateDictionary: \AppState.configs
    /// )
    /// ```
    public func liftCollection<GA, GS, Key: Hashable>(
        action: @escaping (GA) -> ElementAction<Key, ActionType>?,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftCollection(
            action: { ga in action(ga).map { (action: $0.action, element: [Key: StateType].ix(key: $0.id)) } },
            stateContainer: stateDictionary
        )
    }

    /// Lifts to a `Dictionary` via a KeyPath, locating the entry by its key.
    ///
    /// ```swift
    /// // AppAction has: var updateConfig: ElementAction<String, ConfigAction>?
    /// configReducer.liftCollection(action: \AppAction.updateConfig, stateDictionary: \AppState.configs)
    /// ```
    public func liftCollection<GA, GS, Key: Hashable>(
        action: KeyPath<GA, ElementAction<Key, ActionType>?>,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftCollection(action: { $0[keyPath: action] }, stateDictionary: stateDictionary)
    }
}
