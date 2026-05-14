import Foundation

/// A type-erasing, stateless projection of a ``StoreType`` that presents a narrower
/// action and state interface.
///
/// `StoreProjection` is a **struct** — it holds no state of its own. Its `state` property is
/// computed by calling the stored mapping closure on the underlying store's state every time it
/// is accessed. This means:
///
/// - There is no caching or diffing overhead.
/// - Multiple accesses within the same frame may return different values if the store mutated
///   between them (which can't happen on `@MainActor`, but is worth noting conceptually).
/// - If you need caching and notification deduplication, use ``StoreBuffer`` via `.buffer()`.
///
/// ## Global types appear in the init only
///
/// The mapping closures capture the global store types (`GA`, `GS`) at construction time and
/// erase them into the struct's stored closures. The struct's type parameters `Action` and
/// `State` represent the **local** (narrowed) types — the types the feature or view cares about.
///
/// ```swift
/// // Direct construction — global types in init only
/// let counterProj = StoreProjection<CounterAction, CounterState>(
///     store:  appStore,
///     action: { AppAction.counter($0) },
///     state:  { $0.counterState }
/// )
///
/// // Convenience factory on StoreType
/// let counterProj = appStore.projection(
///     action: { AppAction.counter($0) },
///     state:  { $0.counterState }
/// )
/// ```
///
/// ## Collection element projections
///
/// Three additional initialisers project to a single element within a collection:
///
/// - `init(store:element:actionReview:stateCollection:)` — for `Identifiable` elements.
/// - `init(store:element:actionReview:stateCollection:identifier:)` — for custom `Hashable` ids.
/// - `init(store:key:actionReview:stateDictionary:)` — for `[Key: Value]` dictionary values.
///
/// All wrap the element action in an ``ElementAction`` and dispatch it through the global store.
///
/// ## Observation
///
/// Observer registrations are forwarded directly to the underlying store. `willChange` and
/// `didChange` fire whenever the **underlying store** mutates — not just when the projected
/// state slice changes. Use ``StoreBuffer`` if you need notification gating.
///
/// - Note: `StoreProjection` is `@MainActor` and `Sendable`, consistent with ``StoreType``.
@MainActor
public struct StoreProjection<Action: Sendable, State: Sendable>: StoreType {
    private let _state: @MainActor @Sendable () -> State
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void
    private let _observe: @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void,
        @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken

    /// Creates a projection that maps a local action to a global action and projects a
    /// global state to a local state.
    ///
    /// Global store types (`GA`, `GS`) appear only in this initialiser's type parameters and
    /// are captured into the closures — they are not visible on the struct itself.
    ///
    /// ```swift
    /// let counterProj = StoreProjection<CounterAction, CounterState>(
    ///     store:  appStore,                              // Store<AppAction, AppState, AppEnv>
    ///     action: { AppAction.counter($0) },             // CounterAction → AppAction
    ///     state:  { $0.counterState }                    // AppState → CounterState
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType`` to project from.
    ///   - mapAction: Converts a local `Action` into the store's global action type `GA`.
    ///   - mapState: Projects the store's global state type `GS` to the local `State`.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>>(
        store: S,
        action mapAction: @escaping @Sendable (Action) -> GA,
        state mapState: @escaping @MainActor @Sendable (GS) -> State
    ) {
        _state    = { mapState(store.state) }
        _dispatch = { action, source in store.dispatch(mapAction(action), source: source) }
        _observe  = { wc, dc in store.observe(willChange: wc, didChange: dc) }
    }

    /// Creates a projection focused on a single `Identifiable` element in a collection.
    ///
    /// The projected `State` is `C.Element?` — `nil` when no element with the given `id`
    /// exists in the collection. Actions are wrapped in an ``ElementAction`` and lifted
    /// through `actionReview` before reaching the global store.
    ///
    /// ```swift
    /// let todoProj = appStore.projection(
    ///     element: todo.id,
    ///     actionReview: { AppAction.todo($0) },
    ///     stateCollection: \.todos
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType``.
    ///   - id: The `Identifiable.ID` of the target element.
    ///   - actionReview: Wraps `ElementAction<ID, Action>` into the global action type `GA`.
    ///   - stateCollection: Key path from global state `GS` to the collection `C`.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>, C: Collection & Sendable>(
        store: S,
        element id: C.Element.ID,
        actionReview: @escaping @Sendable (ElementAction<C.Element.ID, Action>) -> GA,
        stateCollection: WritableKeyPath<GS, C>
    ) where C.Element: Identifiable & Sendable, C.Element.ID: Hashable & Sendable, State == C.Element? {
        _state    = { store.state[keyPath: stateCollection].first { $0.id == id } }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(id, action: action)), source: source) }
        _observe  = { wc, dc in store.observe(willChange: wc, didChange: dc) }
    }

    /// Creates a projection focused on the first element whose custom `identifier` field matches `id`.
    ///
    /// Use this when the collection's element type is not `Identifiable` or when you want to
    /// focus by a field other than the standard `id` property.
    ///
    /// ```swift
    /// let featureProj = appStore.projection(
    ///     element: "auth",
    ///     actionReview: { AppAction.feature($0) },
    ///     stateCollection: \.features,
    ///     identifier: \.slug
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType``.
    ///   - id: The identifier value to match.
    ///   - actionReview: Wraps `ElementAction<ID, Action>` into the global action type `GA`.
    ///   - stateCollection: Key path from global state `GS` to the collection `C`.
    ///   - identifier: A function that extracts the comparable `ID` from a collection element.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>, C: Collection & Sendable, ID: Hashable & Sendable>(
        store: S,
        element id: ID,
        actionReview: @escaping @Sendable (ElementAction<ID, Action>) -> GA,
        stateCollection: WritableKeyPath<GS, C>,
        identifier: @escaping @Sendable (C.Element) -> ID
    ) where C.Element: Sendable, State == C.Element? {
        _state    = { store.state[keyPath: stateCollection].first { identifier($0) == id } }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(id, action: action)), source: source) }
        _observe  = { wc, dc in store.observe(willChange: wc, didChange: dc) }
    }

    /// Creates a projection focused on a value in a `[Key: Value]` dictionary by key.
    ///
    /// The projected `State` is `Value?` — `nil` when the key is absent from the dictionary.
    ///
    /// ```swift
    /// let configProj = appStore.projection(
    ///     key: "darkMode",
    ///     actionReview: { AppAction.config($0) },
    ///     stateDictionary: \.userSettings
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType``.
    ///   - key: The dictionary key to focus on.
    ///   - actionReview: Wraps `ElementAction<Key, Action>` into the global action type `GA`.
    ///   - stateDictionary: Key path from global state `GS` to the `[Key: Value]` dictionary.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>, Key: Hashable & Sendable, Value: Sendable>(
        store: S,
        key: Key,
        actionReview: @escaping @Sendable (ElementAction<Key, Action>) -> GA,
        stateDictionary: KeyPath<GS, [Key: Value]>
    ) where State == Value? {
        _state    = { store.state[keyPath: stateDictionary][key] }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(key, action: action)), source: source) }
        _observe  = { wc, dc in store.observe(willChange: wc, didChange: dc) }
    }

    /// The current projected state.
    ///
    /// Computed on every access by applying the state mapping closure to the underlying store's
    /// current state. No caching or diffing — use ``StoreBuffer`` if you need deduplication.
    public var state: State { _state() }

    /// Dispatches an action through the action mapping closure to the underlying store.
    ///
    /// - Parameters:
    ///   - action: The local action to dispatch.
    ///   - source: The call-site provenance forwarded unchanged to the underlying store.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }

    /// Forwards the observation registration to the underlying store.
    ///
    /// - Note: Notifications fire on every underlying-store mutation, not only when the
    ///   projected state slice changes. Wrap in ``StoreBuffer`` for filtered notifications.
    ///
    /// - Parameters:
    ///   - willChange: Called before each underlying mutation.
    ///   - didChange: Called after each underlying mutation.
    /// - Returns: A ``SubscriptionToken`` that cancels both callbacks when cancelled.
    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        _observe(willChange, didChange)
    }
}
