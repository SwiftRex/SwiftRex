/// The common interface shared by ``Store``, ``StoreProjection``, ``StoreBuffer``, and any mock.
///
/// Views, coordinators, and tests accept `any StoreType<Action, State>`, letting the real
/// ``Store`` and its derived types be used interchangeably without coupling call sites to
/// concrete types.
///
/// ```swift
/// struct CounterView: View {
///     let store: any StoreType<CounterAction, CounterState>
///
///     var body: some View {
///         Text("\(store.state.count)")
///         Button("+") { store.dispatch(.increment) }
///         Button("−") { store.dispatch(.decrement) }
///     }
/// }
/// ```
///
/// ## Conformers
///
/// | Type | Purpose |
/// |---|---|
/// | ``Store`` | Concrete owner of mutable state — typically one per app |
/// | ``StoreProjection`` | Struct; type-erases action and state via mapping closures; no cached state |
/// | ``StoreBuffer`` | Class; caches state and gates notifications via a `hasChanged` predicate |
///
/// ## Dispatch
///
/// Calling ``dispatch(_:source:)`` enqueues an action into the ``Store``'s three-phase pipeline:
///
/// 1. All ``Behavior/handle`` closures run (pre-mutation).
/// 2. Observers fire `willChange`; all `EndoMut` mutations apply; observers fire `didChange`.
/// 3. All ``Effect`` components are scheduled.
///
/// The convenience overload ``dispatch(_:file:function:line:)`` auto-captures the call site,
/// so provenance is always available for logging and debugging.
///
/// ## Observation
///
/// ``observe(willChange:didChange:)`` registers callbacks for both sides of each state change
/// and returns a ``SubscriptionToken``. Call ``SubscriptionToken/cancel()`` on the token to
/// stop receiving notifications.
///
/// ## @MainActor
///
/// The entire `StoreType` surface is `@MainActor`. State reads and dispatches always happen
/// on the main thread, keeping SwiftUI animation transactions working correctly:
///
/// ```swift
/// // withAnimation and store.dispatch() both run on @MainActor — animations just work
/// Button("Expand") {
///     withAnimation(.easeInOut) { store.dispatch(.toggle) }
/// }
/// ```
///
/// - Note: `StoreType` does not require `AnyObject`, so struct conformers (``StoreProjection``)
///   are allowed.
@MainActor
public protocol StoreType<Action, State>: Sendable {
    /// The action type this store accepts.
    associatedtype Action: Sendable
    /// The state type this store manages.
    associatedtype State: Sendable

    /// The current state snapshot.
    ///
    /// Always accessed on `@MainActor`. For ``Store`` and ``StoreBuffer`` this is a stored
    /// property; for ``StoreProjection`` it is computed by applying the state mapping closure
    /// to the underlying store's state on every access.
    var state: State { get }

    /// Dispatches an action with explicit call-site provenance.
    ///
    /// The ``ActionSource`` carries the file, function, and line where the dispatch originated,
    /// making it available to logging and analytics ``Middleware`` values.
    ///
    /// Prefer the convenience overload ``dispatch(_:file:function:line:)`` which captures the
    /// source automatically.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - source: The call-site origin of the dispatch.
    func dispatch(_ action: Action, source: ActionSource)

    /// Registers callbacks for both sides of each state mutation and returns a cancellation token.
    ///
    /// - `willChange` fires **before** `runEndoMut` — `store.state` still holds the old value.
    ///   This is the correct place to fire `ObservableObject.objectWillChange`.
    /// - `didChange` fires **after** `runEndoMut` — `store.state` holds the new value.
    ///   This is where `@Observable` or push-based UI frameworks should re-render.
    ///
    /// Neither closure receives the state directly; read `store.state` inside them when needed.
    /// The returned ``SubscriptionToken`` cancels **both** callbacks when cancelled — there is
    /// no way to cancel them independently.
    ///
    /// ```swift
    /// let token = store.observe(
    ///     willChange: { print("About to change") },
    ///     didChange:  { print("New state:", store.state) }
    /// )
    ///
    /// // Later — stops both callbacks
    /// token.cancel()
    /// ```
    ///
    /// - Parameters:
    ///   - willChange: Called on `@MainActor` immediately before each state mutation.
    ///   - didChange: Called on `@MainActor` immediately after each state mutation.
    /// - Returns: A ``SubscriptionToken`` that cancels both callbacks when cancelled.
    @discardableResult
    func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken
}

// MARK: - Convenience overloads

extension StoreType {
    /// Dispatches an action, automatically capturing the call site for provenance.
    ///
    /// `#file`, `#function`, and `#line` are resolved at the call site, so logging and
    /// analytics middleware always sees where the dispatch originated.
    ///
    /// Returns `self` so multiple dispatches can be chained in test code:
    ///
    /// ```swift
    /// store
    ///     .dispatch(.login(credentials))
    ///     .dispatch(.loadDashboard)
    /// ```
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    /// - Returns: `self` for chaining.
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
    ///
    /// Shorthand for `observe(willChange: {}, didChange: didChange)`.
    ///
    /// ```swift
    /// let token = store.observe(didChange: { self.updateUI() })
    /// ```
    ///
    /// - Parameter didChange: Called on `@MainActor` after each state mutation.
    /// - Returns: A ``SubscriptionToken`` that cancels the callback when cancelled.
    @discardableResult
    public func observe(didChange: @escaping @MainActor @Sendable () -> Void) -> SubscriptionToken {
        observe(willChange: {}, didChange: didChange)
    }

    /// Observes only pre-mutation notifications.
    ///
    /// Shorthand for `observe(willChange: willChange, didChange: {})`.
    ///
    /// Useful for `ObservableObject` wrappers that need to call `objectWillChange.send()`
    /// before the state changes:
    ///
    /// ```swift
    /// let token = store.observe(willChange: { self.objectWillChange.send() })
    /// ```
    ///
    /// - Parameter willChange: Called on `@MainActor` before each state mutation.
    /// - Returns: A ``SubscriptionToken`` that cancels the callback when cancelled.
    @discardableResult
    public func observe(willChange: @escaping @MainActor @Sendable () -> Void) -> SubscriptionToken {
        observe(willChange: willChange, didChange: {})
    }
}
