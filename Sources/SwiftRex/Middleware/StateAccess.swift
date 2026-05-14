/// A read-only, lazily-evaluated view of the ``Store``'s state passed to ``Middleware/handle``
/// and ``Behavior/handle`` during phase 1 of dispatch.
///
/// `StateAccess` deliberately captures a closure rather than a value snapshot. This means the
/// same `StateAccess` reference yields different values depending on *when* you call
/// ``snapshotState()``:
///
/// - **During phase 1** (`Behavior.handle` / `Middleware.handle`): returns the **pre-mutation**
///   state — the state as it was before any `EndoMut` ran.
/// - **During phase 3** (inside the returned `Reader` or `produce` closure): returns the
///   **post-mutation** state — all mutations from phase 2 are visible.
///
/// ```swift
/// Middleware<MyAction, MyState, MyEnvironment> { action, state in
///     let pre = state.snapshotState()     // pre-mutation state (phase 1)
///
///     return Reader { env in
///         let post = state.snapshotState()  // post-mutation state (phase 3)
///         return .just(.log(before: pre, after: post))
///     }
/// }
/// ```
///
/// ## Store deallocation
///
/// ``snapshotState()`` returns `nil` when the Store has been deallocated. Long-running effects
/// that hold a `StateAccess` reference should treat `nil` as a signal to stop work and call
/// `complete()` on their subscription:
///
/// ```swift
/// // In a long-lived effect
/// guard let current = stateAccess.snapshotState() else {
///     complete()   // Store is gone; stop producing actions
///     return
/// }
/// ```
///
/// ## Functor
///
/// `StateAccess` is a **Functor**: ``map(_:)`` projects to a sub-state, and ``flatMap(_:)``
/// handles optional projections (e.g., focusing on a specific enum case). Lifting operations
/// use these to give feature middlewares a narrowly-typed view:
///
/// ```swift
/// // Inside liftState(_:) — feature middleware sees AuthState, not AppState
/// let localAccess = globalAccess.map { $0.authState }
/// ```
///
/// - Note: `StateAccess` is `@MainActor`. ``snapshotState()`` must be called on the main
///   actor, which is always the case during `Behavior.handle` (phase 1) and when the Store
///   runs the `Reader` (phase 3 is also `@MainActor`).
@MainActor
public struct StateAccess<State: Sendable> {
    private let _get: @Sendable @MainActor () -> State?

    package init(_ get: @escaping @Sendable @MainActor () -> State?) {
        _get = get
    }

    /// Returns a snapshot of the current state, or `nil` if the ``Store`` has been deallocated.
    ///
    /// The returned value reflects the state at the moment of the call:
    /// - Called during phase 1 (`Behavior.handle`): returns pre-mutation state.
    /// - Called during phase 3 (inside `Reader` / `produce` closures): returns post-mutation state.
    ///
    /// - Returns: The current state, or `nil` when the Store has been deallocated.
    public func snapshotState() -> State? { _get() }
}

// MARK: - Functor

extension StateAccess {
    /// Projects this access to a sub-state using a transformation function.
    ///
    /// The full `State` is still read and then transformed — there is no partial-read optimisation.
    /// The resulting `StateAccess<LocalState>` follows the same timing rules: calling it during
    /// phase 1 yields the projection of pre-mutation state; calling it during phase 3 yields the
    /// projection of post-mutation state.
    ///
    /// ```swift
    /// // Give a feature middleware only the sub-state it cares about
    /// let authAccess: StateAccess<AuthState> = globalAccess.map { $0.authState }
    /// ```
    ///
    /// - Parameter f: A transformation from `State` to `LocalState`.
    /// - Returns: A `StateAccess<LocalState>` that applies `f` on every ``snapshotState()`` call.
    public func map<LocalState: Sendable>(
        _ f: @escaping @Sendable @MainActor (State) -> LocalState
    ) -> StateAccess<LocalState> {
        StateAccess<LocalState> { self.snapshotState().map(f) }
    }

    /// Projects this access to an optional sub-state.
    ///
    /// Returns `nil` when the Store is deallocated **or** when `f` returns `nil`. The latter
    /// is useful when focusing on a specific enum case that may not be active:
    ///
    /// ```swift
    /// // State is nil when the Store is gone OR when the app is not in .loggedIn state
    /// let loggedInAccess: StateAccess<UserSession> = globalAccess.flatMap {
    ///     guard case .loggedIn(let session) = $0 else { return nil }
    ///     return session
    /// }
    /// ```
    ///
    /// - Parameter f: A partial transformation from `State` to `LocalState?`.
    /// - Returns: A `StateAccess<LocalState>` that returns `nil` when either the Store is
    ///   gone or `f` returns `nil`.
    public func flatMap<LocalState: Sendable>(
        _ f: @escaping @Sendable @MainActor (State) -> LocalState?
    ) -> StateAccess<LocalState> {
        StateAccess<LocalState> { self.snapshotState().flatMap(f) }
    }
}
