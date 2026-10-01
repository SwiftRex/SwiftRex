// SPDX-License-Identifier: Apache-2.0

import DataStructure

/// A type-erasing, stateless projection of a ``StoreType`` that presents a narrower
/// action and state interface.
///
/// `StoreProjection` is a **struct** — it holds no state of its own. Its ``stateStream`` is the underlying
/// store's stream mapped through the state closure, so the map runs once per upstream change for each
/// observer — never "on every read" (a store can't be read). To skip the map when its input didn't change,
/// put a ``StoreBuffer`` before it: `store.buffer().projection(…)`.
///
/// ## Global types appear in the init only
///
/// The mapping closures capture the global store types (`GA`, `GS`) at construction time and
/// erase them into the struct's stored closures. The struct's type parameters `Action` and
/// `State` represent the **local** (narrowed) types — the types the feature or view cares about.
///
/// ```swift
/// // Through a Relay scope — the usual way (inline, or a declared `ScopeOf` scope)
/// let counterProj = appStore.projection(.action(\.counter).state(\.counter))
///
/// // Through closures — for a derived view state no key path expresses
/// let counterView = StoreProjection<CounterAction, CounterViewState>(
///     store: counterProj,
///     action: { $0 },
///     state: { CounterViewState(label: "\($0.count)") }
/// )
/// ```
///
/// ## Collection element projections
///
/// One element of a collection is a ``StoreCollectionFocus``, made through a collection scope:
/// `store.projection(.action(\.row).state(\.rows), element: id)` (also `.state(\.rows, id: \.slug)`,
/// `.state(indexed: \.rows)`, `.state(dictionary: \.byKey)`). The older element initialisers below
/// (`init(store:element:actionReview:stateCollection:)` and siblings) remain, with a linear scan per change.
///
/// ## Observation
///
/// ``stateStream`` delivers the projected state whenever the **underlying store** changes — not only when
/// the projected slice changed. Put a ``StoreBuffer`` after it (`.buffer()`) to skip repeats.
///
/// - Note: `StoreProjection` is `@MainActor` and `Sendable`, consistent with ``StoreType``.
@MainActor
public struct StoreProjection<Action: Sendable, State: Sendable>: StoreType {
    /// The projected state over time: the underlying stream, mapped.
    public let stateStream: StateStream<State>
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void

    /// A projection over an already-derived stream — for stream operators no state closure expresses.
    package init<S: StoreType>(store: S, action mapAction: @escaping @Sendable (Action) -> S.Action, stateStream: StateStream<State>) {
        self.stateStream = stateStream
        _dispatch = { action, source in store.dispatch(mapAction(action), source: source) }
    }

    /// Creates a projection that maps a local action to a global action and projects a
    /// global state to a local state.
    ///
    /// Global store types (`GA`, `GS`) appear only in this initialiser's type parameters and
    /// are captured into the closures — they are not visible on the struct itself.
    ///
    /// For a plain slice prefer `store.projection(.action(\.counter).state(\.counter))`; the closures are for a
    /// derived view state:
    ///
    /// ```swift
    /// let counterView = StoreProjection<CounterAction, CounterViewState>(
    ///     store: counterStore, // StoreProjection<CounterAction, CounterState>
    ///     action: { $0 },
    ///     state: { CounterViewState(label: "\($0.count)") } // CounterState → CounterViewState
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
        stateStream = store.stateStream.mapIsolated(mapState)
        _dispatch = { action, source in store.dispatch(mapAction(action), source: source) }
    }

    /// Creates a projection whose action **and** state maps are `Reader`s over an `Environment`,
    /// applied with the supplied `environment` at creation.
    ///
    /// Use it when the projection depends on live dependencies on either side — locale-aware
    /// formatting on the state map, resilient/locale-aware parsing on the action map. The plain
    /// ``init(store:action:state:)`` is the `Environment == Void` case (no `Reader`).
    ///
    /// The environment is applied once, here — whoever projects holds it (they built, or hold, the
    /// underlying store). Both `Reader`s are run and their resulting closures captured.
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType`` to project from.
    ///   - environment: The environment supplied to both maps.
    ///   - mapAction: A `Reader<Environment, (Action) -> GA>` — the environment-aware action map.
    ///   - mapState: A `Reader<Environment, (GS) -> State>` — the environment-aware state map.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>, Environment>(
        store: S,
        environment: Environment,
        action mapAction: Reader<Environment, @Sendable (Action) -> GA>,
        state mapState: Reader<Environment, @MainActor @Sendable (GS) -> State>
    ) {
        let action = mapAction(environment)
        let state = mapState(environment)
        stateStream = store.stateStream.mapIsolated(state)
        _dispatch = { a, source in store.dispatch(action(a), source: source) }
    }

    /// Creates a projection focused on a single `Identifiable` element in a collection.
    ///
    /// The projected `State` is `C.Element?` — `nil` when no element with the given `id`
    /// exists in the collection. Actions are wrapped in an ``ElementAction`` and lifted
    /// through `actionReview` before reaching the global store.
    ///
    /// Prefer the collection scope, which finds the element through a per-observer hint instead of a scan:
    ///
    /// ```swift
    /// let todo = appStore.projection(.action(\.todo).state(\.todos), element: todo.id) // StoreCollectionFocus
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
        stateCollection: KeyPath<GS, C>
    ) where C.Element: Identifiable & Sendable, C.Element.ID: Hashable & Sendable, State == C.Element? {
        // O(n) per upstream change: a linear scan. See the perf discussion on
        // StoreType.projection(element:actionReview:stateCollection:) for the Array/dictionary trade-off.
        stateStream = store.stateStream.map { $0[keyPath: stateCollection].first { $0.id == id } }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(id, action: action)), source: source) }
    }

    /// Creates a projection focused on the first element whose custom `identifier` field matches `id`.
    ///
    /// Use this when the collection's element type is not `Identifiable` or when you want to
    /// focus by a field other than the standard `id` property.
    ///
    /// Prefer the collection scope with a custom id:
    ///
    /// ```swift
    /// let feature = appStore.projection(.action(\.feature).state(\.features, id: \.slug), element: "auth")
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
        stateCollection: KeyPath<GS, C>,
        identifier: @escaping @Sendable (C.Element) -> ID
    ) where C.Element: Sendable, State == C.Element? {
        // O(n) per upstream change: a linear scan. See the perf discussion on
        // StoreType.projection(element:actionReview:stateCollection:identifier:) for the trade-off.
        stateStream = store.stateStream.map { $0[keyPath: stateCollection].first { identifier($0) == id } }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(id, action: action)), source: source) }
    }

    /// Creates a projection focused on a value in a `[Key: Value]` dictionary by key.
    ///
    /// The projected `State` is `Value?` — `nil` when the key is absent from the dictionary.
    ///
    /// Prefer the dictionary collection scope:
    ///
    /// ```swift
    /// let config = appStore.projection(.action(\.config).state(dictionary: \.userSettings), element: "darkMode")
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
        stateStream = store.stateStream.map { $0[keyPath: stateDictionary][key] }
        _dispatch = { action, source in store.dispatch(actionReview(ElementAction(key, action: action)), source: source) }
    }

    /// Dispatches an action through the action mapping closure to the underlying store.
    ///
    /// - Parameters:
    ///   - action: The local action to dispatch.
    ///   - source: The call-site provenance forwarded unchanged to the underlying store.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }
}
