/// A read-only, `@MainActor`-only context passed to ``Behavior/handle`` and
/// ``Middleware/handle`` during phase 1 of dispatch (pre-mutation).
///
/// `PreReducerContext` bundles two pieces of information that are only meaningful during phase 1:
///
/// - ``source``: the call-site that dispatched the current action.
/// - ``stateBefore``: the store state as it was *before* any `EndoMut` from this dispatch cycle ran.
///
/// ## Why non-Sendable
///
/// `PreReducerContext` deliberately does **not** conform to `Sendable`. This prevents
/// accidental capture of pre-mutation state into the `produce` or `Reader` closures that run in
/// phase 3, where the state has already mutated. Attempting to capture a `PreReducerContext`
/// into a `@Sendable` closure is a **compile-time error**, guiding the caller toward
/// ``PostReducerContext`` for any phase-3 state reads.
///
/// ```swift
/// Behavior<MyAction, MyState, MyEnvironment> { action, context in
///     let before = context.stateBefore   // ✅ safe — @MainActor, pre-mutation
///
///     return .reduce { $0.count += 1 }
///            .react { ctx in
///                // ✅ phase 3: use PostReducerContext
///                return .just(.log(before: before, after: ctx.liveState?.count))
///            }
/// }
/// ```
///
/// ## Functor (covariant on State)
///
/// `PreReducerContext` is a **Functor** on `State` via ``map(_:)`` and ``compactMap(_:)``.
/// Lifting operations use these to give feature behaviors/middlewares a narrowly-typed state view:
///
/// ```swift
/// // Inside liftState(_:) — feature sees AuthState, not AppState
/// let localContext = context.map { $0.authState }
/// ```
///
/// - Note: The stored `stateGetter` is intentionally `@Sendable` so lifting transforms can safely
///   extract it and compose it when constructing child `PreReducerContext` instances. The
///   non-Sendability of the struct itself comes from a non-`@Sendable` sentinel property.
@MainActor
public struct PreReducerContext<State: Sendable> {
    // MARK: - Public

    /// The call-site that dispatched the current action.
    ///
    /// Carries the `file`, `function`, and `line` of the `store.dispatch(...)` call or the
    /// effect that re-dispatched the action. Useful for logging, tracing, and analytics.
    public let source: ActionSource

    /// The state immediately before this dispatch cycle's mutations ran.
    ///
    /// Always called on `@MainActor`. Returns `nil` if the ``Store`` has been deallocated.
    public var stateBefore: State? { stateGetter() }

    // MARK: - Package-internal

    /// The raw getter closure. Marked `@Sendable` so lifting transforms can extract it and
    /// compose it into child `PreReducerContext` instances without violating Sendable rules.
    package let stateGetter: @Sendable @MainActor () -> State?

    // MARK: - Non-Sendable sentinel

    // A non-`@Sendable` stored property prevents the compiler from automatically synthesising
    // a `Sendable` conformance for this struct. This intentionally makes `PreReducerContext`
    // non-Sendable so it cannot be captured inside phase-3 `@Sendable` closures.
    // An empty closure literal allocates no heap memory, so there is no performance cost.
    private let _nonSendable: () -> Void

    // MARK: - Init

    package init(source: ActionSource, getter: @escaping @Sendable @MainActor () -> State?) {
        self.source = source
        stateGetter = getter
        _nonSendable = {}
    }
}

// MARK: - Functor (covariant on State)

extension PreReducerContext {
    /// Projects this context to a narrower state type using a total transformation.
    ///
    /// The full `State` is read and then transformed — there is no partial-read optimisation.
    /// The resulting `PreReducerContext<LocalState>` follows the same timing rules as the
    /// original: ``stateBefore`` yields the projection of pre-mutation state.
    ///
    /// ```swift
    /// // Give a feature behavior only the sub-state it cares about
    /// let localContext = context.map { $0.authState }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` transformation from `State` to `LocalState`.
    /// - Returns: A `PreReducerContext<LocalState>` that applies `f` on every ``stateBefore`` read.
    public func map<LocalState: Sendable>(
        _ f: @escaping @Sendable (State) -> LocalState
    ) -> PreReducerContext<LocalState> {
        PreReducerContext<LocalState>(source: source, getter: { stateGetter().map(f) })
    }

    /// Projects this context to a narrower state type using a partial transformation.
    ///
    /// The resulting ``stateBefore`` is `nil` when the Store is deallocated **or** when `f`
    /// returns `nil`. Useful for focusing on a specific enum case that may not be active:
    ///
    /// ```swift
    /// // stateBefore is nil when not in .loggedIn state
    /// let localContext = context.compactMap(AppState.prism.loggedIn.preview)
    /// ```
    ///
    /// - Parameter f: A `@Sendable` partial transformation from `State` to `LocalState?`.
    /// - Returns: A `PreReducerContext<LocalState>` returning `nil` when either the Store is
    ///   gone or `f` returns `nil`.
    public func compactMap<LocalState: Sendable>(
        _ f: @escaping @Sendable (State) -> LocalState?
    ) -> PreReducerContext<LocalState> {
        PreReducerContext<LocalState>(source: source, getter: { stateGetter().flatMap(f) })
    }
}
