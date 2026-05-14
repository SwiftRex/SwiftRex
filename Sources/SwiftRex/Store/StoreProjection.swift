import Foundation

/// A type-erased projection of a `StoreType` that maps its action and state types to a
/// narrower local interface. Holds no state — `state` is computed from the underlying
/// store on every access.
///
/// `StoreProjection` owns the mapping logic: the global store types appear only in the
/// initialiser and are erased into the stored closures.
///
/// ```swift
/// // Direct — global types in the init only
/// let proj = StoreProjection(
///     store:  appStore,
///     action: AppAction.counter,
///     state:  \.counterState
/// )
///
/// // Convenience factory on StoreType (delegates to this init)
/// let proj = appStore.projection(action: AppAction.counter, state: \.counterState)
/// ```
@MainActor
public struct StoreProjection<Action: Sendable, State: Sendable>: StoreType {

    private let _state:    @MainActor @Sendable () -> State
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void
    private let _observe:  @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void,
        @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken

    /// Primary init. Global store types (`GA`, `GS`) appear here only and are captured
    /// into the map closures — they are not exposed as type parameters on the struct.
    public init<GA: Sendable, GS: Sendable, S: StoreType<GA, GS>>(
        store: S,
        action mapAction: @escaping @Sendable (Action) -> GA,
        state mapState: @escaping @MainActor @Sendable (GS) -> State
    ) {
        _state    = { mapState(store.state) }
        _dispatch = { action, source in store.dispatch(mapAction(action), source: source) }
        _observe  = { wc, dc in store.observe(willChange: wc, didChange: dc) }
    }

    /// Projects to a single `Identifiable` element in a collection.
    /// `State` must be `C.Element?`; global types appear in the init only.
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

    /// Projects to the first element whose `identifier` field matches `id`.
    /// `State` must be `C.Element?`; global types appear in the init only.
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

    /// Projects to a value in a `[Key: Value]` dictionary by key.
    /// `State` must be `Value?`; global types appear in the init only.
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

    public var state: State { _state() }

    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }

    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange:  @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        _observe(willChange, didChange)
    }
}
