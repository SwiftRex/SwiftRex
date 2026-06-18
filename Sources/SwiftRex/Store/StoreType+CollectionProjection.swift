// MARK: - Collection element projections
//
// Convenience factories on StoreType — each delegates to the corresponding
// StoreProjection.init where the mapping logic lives.

// MARK: - Identifiable element

extension StoreType {
    /// Creates a ``StoreProjection`` focused on a single `Identifiable` element within a collection.
    ///
    /// The projected state is `C.Element?` — `nil` when no element with the given `id` exists
    /// in the collection. Dispatched actions are wrapped in an ``ElementAction`` and lifted
    /// through `actionReview` before reaching the underlying store.
    ///
    /// This enables per-element store projections in list views without the view needing to
    /// know where the collection lives in the global state:
    ///
    /// ```swift
    /// // In a list cell view — only knows the todo id and todo-level actions
    /// let todoStore = appStore.projection(
    ///     element: todo.id,
    ///     actionReview: { AppAction.todo($0) },
    ///     stateCollection: \AppState.todos
    /// )
    /// // todoStore: StoreProjection<TodoAction, Todo?>
    /// ```
    ///
    /// **Performance.** The element is resolved with a linear `first { $0.id == id }` scan **on
    /// every state read** — i.e. on every observation/render — so projecting one element out of a
    /// collection of `n` costs O(n) per read. Choosing a container:
    ///
    /// - Prefer a plain `Array` (this factory) for **small collections**, for collections with
    ///   **frequent inserts / removals / reordering**, or **whenever display order matters** — the
    ///   O(n) read is negligible at small `n`, and `Array` keeps insertion order and cheap
    ///   structural edits.
    /// - For **large, read-heavy (or edit-in-place-by-id) collections where order is irrelevant**,
    ///   store the data as `[ID: Element]` and use ``projection(key:actionReview:stateDictionary:)``
    ///   instead — dictionary lookup is O(1) per read.
    /// - Caveat: a dictionary is **unordered**, so driving a list UI directly from one produces
    ///   arbitrary, unstable row order. If you need both O(1) by-id access *and* stable order,
    ///   keep a separate `[ID]` order array alongside it, or wait for a dedicated ordered indexed
    ///   container. Do **not** reach for a dictionary purely to avoid the O(n) read when order
    ///   matters — accept the linear read on the `Array` instead.
    ///
    /// Delegates to ``StoreProjection/init(store:element:actionReview:stateCollection:)``.
    ///
    /// - Parameters:
    ///   - id: The `Identifiable.ID` of the target element.
    ///   - actionReview: Converts `ElementAction<C.Element.ID, SubAction>` to this store's
    ///     global `Action` type.
    ///   - stateCollection: Key path from this store's `State` to the collection `C`.
    /// - Returns: A ``StoreProjection`` whose state is `C.Element?` and whose actions are
    ///   wrapped in ``ElementAction`` keyed by `id`.
    public func projection<SubAction: Sendable, C: Collection & Sendable>(
        element id: C.Element.ID,
        actionReview: @escaping @Sendable (ElementAction<C.Element.ID, SubAction>) -> Action,
        stateCollection: KeyPath<State, C>
    ) -> StoreProjection<SubAction, C.Element?>
    where C.Element: Identifiable & Sendable, C.Element.ID: Hashable & Sendable {
        StoreProjection(store: self, element: id, actionReview: actionReview, stateCollection: stateCollection)
    }
}

// MARK: - Custom Hashable identifier

extension StoreType {
    /// Creates a ``StoreProjection`` focused on the first element whose `identifier` field
    /// matches `id`.
    ///
    /// Use this when the collection's element type is not `Identifiable`, or when you want
    /// to focus by a field other than the standard `id` property:
    ///
    /// ```swift
    /// // Focus by a custom "slug" field rather than Identifiable.id
    /// let featureStore = appStore.projection(
    ///     element: "auth",
    ///     actionReview: { AppAction.feature($0) },
    ///     stateCollection: \AppState.features,
    ///     identifier: \.slug
    /// )
    /// // featureStore: StoreProjection<FeatureAction, Feature?>
    /// ```
    ///
    /// **Performance.** Same O(n)-per-read cost as
    /// ``projection(element:actionReview:stateCollection:)`` — a linear `first(where:)` scan runs on
    /// every state read. See that factory's discussion for when to prefer an `Array`, a dictionary,
    /// or a dedicated ordered indexed container.
    ///
    /// Delegates to ``StoreProjection/init(store:element:actionReview:stateCollection:identifier:)``.
    ///
    /// - Parameters:
    ///   - id: The identifier value to match against elements.
    ///   - actionReview: Converts `ElementAction<ID, SubAction>` to this store's global `Action` type.
    ///   - stateCollection: Key path from this store's `State` to the collection `C`.
    ///   - identifier: A function that extracts the comparable `ID` from a collection element.
    /// - Returns: A ``StoreProjection`` whose state is `C.Element?` (the first matching element).
    public func projection<SubAction: Sendable, C: Collection & Sendable, ID: Hashable & Sendable>(
        element id: ID,
        actionReview: @escaping @Sendable (ElementAction<ID, SubAction>) -> Action,
        stateCollection: KeyPath<State, C>,
        identifier: @escaping @Sendable (C.Element) -> ID
    ) -> StoreProjection<SubAction, C.Element?>
    where C.Element: Sendable {
        StoreProjection(store: self, element: id, actionReview: actionReview, stateCollection: stateCollection, identifier: identifier)
    }
}

// MARK: - Dictionary key

extension StoreType {
    /// Creates a ``StoreProjection`` focused on a value in a `[Key: Value]` dictionary by key.
    ///
    /// The projected state is `Value?` — `nil` when the key is absent from the dictionary.
    /// Dispatched actions are wrapped in an ``ElementAction`` keyed by `key` and lifted through
    /// `actionReview` before reaching the underlying store:
    ///
    /// ```swift
    /// // Focus on a specific user-settings entry
    /// let settingStore = appStore.projection(
    ///     key: "notifications",
    ///     actionReview: { AppAction.setting($0) },
    ///     stateDictionary: \AppState.userSettings
    /// )
    /// // settingStore: StoreProjection<SettingAction, SettingValue?>
    /// ```
    ///
    /// **Performance.** Dictionary lookup is O(1) per read — the O(1) counterpart to the
    /// `Array`-based ``projection(element:actionReview:stateCollection:)``. Prefer this for large,
    /// read-heavy collections keyed by id where ordering is **not** required; if you need stable
    /// display order, see that factory's discussion (a dictionary alone cannot provide it).
    ///
    /// Delegates to ``StoreProjection/init(store:key:actionReview:stateDictionary:)``.
    ///
    /// - Parameters:
    ///   - key: The dictionary key to focus on.
    ///   - actionReview: Converts `ElementAction<Key, SubAction>` to this store's global `Action` type.
    ///   - stateDictionary: Key path from this store's `State` to the `[Key: Value]` dictionary.
    /// - Returns: A ``StoreProjection`` whose state is `Value?` (the value for `key`, or `nil`).
    public func projection<SubAction: Sendable, Key: Hashable & Sendable, Value: Sendable>(
        key: Key,
        actionReview: @escaping @Sendable (ElementAction<Key, SubAction>) -> Action,
        stateDictionary: KeyPath<State, [Key: Value]>
    ) -> StoreProjection<SubAction, Value?> {
        StoreProjection(store: self, key: key, actionReview: actionReview, stateDictionary: stateDictionary)
    }
}
