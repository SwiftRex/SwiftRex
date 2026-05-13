/// A read-only, lazily-evaluated view of the Store's state passed to `Middleware.handle`.
///
/// `snapshotState()` returns `State?` — `nil` means the Store has been deallocated.
/// Long-running effects that capture `StateAccess` should treat `nil` as a signal to
/// stop work and call `complete()`.
///
/// `StateAccess` is a **Functor**: `map` projects to a sub-state so that a lifted
/// middleware receives only the slice it cares about, keeping its type parameters narrow.
///
/// **Two access points — one value, different moments:**
/// ```swift
/// Middleware { action, state in
///     let pre = state.snapshotState()     // pre-reducer state (called during handle)
///
///     return Reader { env in
///         let post = state.snapshotState()  // post-reducer state (called when Reader runs)
///         return .just(.update(pre, post))
///     }
/// }
/// ```
@MainActor
public struct StateAccess<State: Sendable>: Sendable {
    private let _get: @Sendable @MainActor () -> State?

    package init(_ get: @escaping @Sendable @MainActor () -> State?) {
        _get = get
    }

    /// Returns a copy of the current state, or `nil` if the Store has been deallocated.
    public func snapshotState() -> State? { _get() }
}

// MARK: - Functor

extension StateAccess {
    /// Projects this access to a sub-state. The copy cost is the same — the full `State` is
    /// still read and discarded — but the middleware receives only `LocalState`.
    public func map<LocalState: Sendable>(
        _ f: @escaping @Sendable @MainActor (State) -> LocalState
    ) -> StateAccess<LocalState> {
        StateAccess<LocalState> { self.snapshotState().map(f) }
    }

    /// Projects this access to an optional sub-state. Returns `nil` when the Store is gone
    /// OR when `f` returns `nil` (e.g. the focused enum case is not active).
    public func flatMap<LocalState: Sendable>(
        _ f: @escaping @Sendable @MainActor (State) -> LocalState?
    ) -> StateAccess<LocalState> {
        StateAccess<LocalState> { self.snapshotState().flatMap(f) }
    }
}
