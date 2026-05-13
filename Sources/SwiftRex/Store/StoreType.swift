/// The common interface shared by `Store` and `StoreProjection`.
///
/// Views, coordinators, and tests accept `any StoreType<Action, State>`, letting the real
/// `Store` and a projected `StoreProjection` be used interchangeably.
///
/// ```swift
/// struct CounterView: View {
///     let store: any StoreType<CounterAction, CounterState>
///
///     var body: some View {
///         Button("+") { store.dispatch(.increment) }
///     }
/// }
/// ```
@MainActor
public protocol StoreType<Action, State>: Sendable {
    associatedtype Action: Sendable
    associatedtype State

    /// Current state snapshot. Always accessed on `@MainActor`.
    var state: State { get }

    /// Dispatches an action with explicit call-site provenance.
    func dispatch(_ action: Action, source: ActionSource)

    /// Registers callbacks for both sides of each state mutation.
    ///
    /// - `willChange` fires **before** `runEndoMut` — `store.state` still holds the old value.
    /// - `didChange` fires **after** `runEndoMut` — `store.state` holds the new value.
    ///
    /// Neither closure receives the state directly; read `store.state` when you need it.
    /// The returned token cancels both callbacks when cancelled.
    @discardableResult
    func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken
}

extension StoreType {
    /// Dispatches an action, automatically capturing the call site for provenance.
    @discardableResult
    public func dispatch(
        _ action: Action,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        dispatch(action, source: ActionSource(file: file, function: function, line: line))
        return self
    }

    /// Observes only post-mutation notifications.
    @discardableResult
    public func observe(didChange: @escaping @MainActor @Sendable () -> Void) -> SubscriptionToken {
        observe(willChange: {}, didChange: didChange)
    }

    /// Observes only pre-mutation notifications.
    @discardableResult
    public func observe(willChange: @escaping @MainActor @Sendable () -> Void) -> SubscriptionToken {
        observe(willChange: willChange, didChange: {})
    }

    /// Projects this store to a narrower action and state interface.
    ///
    /// The projection holds no state of its own — `state` is re-computed on every access
    /// by applying `mapState` to the underlying store's current state.
    ///
    /// ```swift
    /// let counterProjection = appStore.projection(
    ///     action: AppAction.counter,
    ///     state:  \.counterState
    /// )
    /// ```
    public func projection<LocalAction: Sendable, LocalState: Sendable>(
        action mapAction: @escaping @Sendable (LocalAction) -> Action,
        state mapState: @escaping @MainActor @Sendable (State) -> LocalState
    ) -> StoreProjection<LocalAction, LocalState> {
        StoreProjection(
            state:    { mapState(self.state) },
            dispatch: { action, source in self.dispatch(mapAction(action), source: source) },
            observe:  { willChange, didChange in self.observe(willChange: willChange, didChange: didChange) }
        )
    }
}
