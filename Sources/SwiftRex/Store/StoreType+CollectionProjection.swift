// MARK: - Collection element projections
//
// Convenience factories on StoreType — each delegates to the corresponding
// StoreProjection.init where the mapping logic lives.

// MARK: - Identifiable element

extension StoreType {
    /// Projects to a single `Identifiable` element in a collection.
    /// State is `Element?` — `nil` when the element with `id` is absent.
    ///
    /// ```swift
    /// store.projection(
    ///     element: todo.id,
    ///     actionReview: { AppAction(updateTodo: $0) },
    ///     stateCollection: \.todos
    /// )
    /// ```
    public func projection<SubAction: Sendable, C: Collection & Sendable>(
        element id: C.Element.ID,
        actionReview: @escaping @Sendable (ElementAction<C.Element.ID, SubAction>) -> Action,
        stateCollection: WritableKeyPath<State, C>
    ) -> StoreProjection<SubAction, C.Element?>
    where C.Element: Identifiable & Sendable, C.Element.ID: Hashable & Sendable {
        StoreProjection(store: self, element: id, actionReview: actionReview, stateCollection: stateCollection)
    }
}

// MARK: - Custom Hashable identifier

extension StoreType {
    /// Projects to the first element whose `identifier` field matches `id`.
    ///
    /// ```swift
    /// store.projection(
    ///     element: "auth",
    ///     actionReview: { AppAction(updateFeature: $0) },
    ///     stateCollection: \.features,
    ///     identifier: \.slug
    /// )
    /// ```
    public func projection<SubAction: Sendable, C: Collection & Sendable, ID: Hashable & Sendable>(
        element id: ID,
        actionReview: @escaping @Sendable (ElementAction<ID, SubAction>) -> Action,
        stateCollection: WritableKeyPath<State, C>,
        identifier: @escaping @Sendable (C.Element) -> ID
    ) -> StoreProjection<SubAction, C.Element?>
    where C.Element: Sendable {
        StoreProjection(store: self, element: id, actionReview: actionReview, stateCollection: stateCollection, identifier: identifier)
    }
}

// MARK: - Dictionary key

extension StoreType {
    /// Projects to a value in a `[Key: Value]` dictionary by key.
    /// State is `Value?` — `nil` when the key is absent.
    ///
    /// ```swift
    /// store.projection(
    ///     key: "theme",
    ///     actionReview: { AppAction(updateConfig: $0) },
    ///     stateDictionary: \.configs
    /// )
    /// ```
    public func projection<SubAction: Sendable, Key: Hashable & Sendable, Value: Sendable>(
        key: Key,
        actionReview: @escaping @Sendable (ElementAction<Key, SubAction>) -> Action,
        stateDictionary: KeyPath<State, [Key: Value]>
    ) -> StoreProjection<SubAction, Value?> {
        StoreProjection(store: self, key: key, actionReview: actionReview, stateDictionary: stateDictionary)
    }
}
