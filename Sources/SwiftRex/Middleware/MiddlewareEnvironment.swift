import CoreFP
import DataStructure

/// The combined context passed to a ``MiddlewareReader`` when the ``Store`` runs phase 3.
///
/// `MiddlewareEnvironment` pairs the injected `Environment` with a live `stateAccess` closure
/// that reads post-mutation state directly from the `@MainActor` Store. Because the closure
/// is itself `@MainActor`, middleware writers can call it without `assumeIsolated`:
///
/// ```swift
/// Middleware<SearchAction, SearchState, SearchEnvironment>.handle { _, stateAccess in
///     let pre = stateAccess.snapshotState()   // phase 1 — @MainActor, safe
///     return MiddlewareReader { ctx in          // phase 3 — @MainActor closure
///         let post = ctx.stateAccess()          // post-mutation state, no assumeIsolated needed
///         let query = ctx.environment.pendingQuery
///         return query.map { q in
///             ctx.environment.api.search(q).asEffect()
///         } ?? .empty
///     }
/// }
/// ```
public struct MiddlewareEnvironment<Environment: Sendable, State: Sendable>: Sendable {
    /// The injected environment for this dispatch cycle.
    public let environment: Environment

    /// A `@MainActor` closure that reads the current state from the Store.
    ///
    /// Returns the **post-mutation** state when called from inside a ``MiddlewareReader``
    /// closure (phase 3 — after all `EndoMut` values have been applied). Returns `nil` when
    /// the Store has been deallocated.
    public let stateAccess: @MainActor @Sendable () -> State?

    public init(
        environment: Environment,
        stateAccess: @escaping @MainActor @Sendable () -> State?
    ) {
        self.environment = environment
        self.stateAccess = stateAccess
    }
}

// MARK: - MiddlewareReader

/// A deferred, `@MainActor`-isolated computation that maps a ``MiddlewareEnvironment`` to an
/// ``Effect``.
///
/// `MiddlewareReader` is the return type of ``Middleware/handle``. Unlike the plain
/// `Reader<Environment, Effect<Action>>`, it carries typed `State` access alongside the
/// environment, and its `run` closure is `@MainActor` — so calling `ctx.stateAccess()` inside
/// needs no `assumeIsolated` workaround:
///
/// ```swift
/// // Phase 1: middleware.handle is @MainActor — stateAccess.snapshotState() is safe here too
/// Middleware<MyAction, MyState, MyEnvironment>.handle { _, stateAccess in
///     let pre = stateAccess.snapshotState()   // pre-mutation
///
///     return MiddlewareReader { ctx in          // phase 3 — @MainActor
///         let post = ctx.stateAccess()          // post-mutation — no assumeIsolated!
///         return .just(.logged(before: pre, after: post))
///     }
/// }
/// ```
///
/// ## Composition
///
/// `MiddlewareReader` is a **Semigroup** and **Monoid** — use ``combine(_:_:)`` to merge two
/// readers whose effects run concurrently, and ``identity`` / ``doNothing`` as the no-op element.
///
/// The ``map(_:)`` and ``contramapEnvironment(_:)`` combinators support the action and environment
/// axes; ``liftState(_:)-9u0q6`` and ``liftState(_:)-5xz5l`` support the state axis.
public struct MiddlewareReader<Action: Sendable, Environment: Sendable, State: Sendable>: Sendable {
    /// The deferred computation.
    ///
    /// - Called on `@MainActor` in phase 3 by the ``Store``.
    /// - `ctx.stateAccess()` reflects post-mutation state at call time.
    public let run: @MainActor @Sendable (MiddlewareEnvironment<Environment, State>) -> Effect<Action>

    /// Creates a `MiddlewareReader` from a closure.
    ///
    /// - Parameter fn: The `@MainActor @Sendable` closure mapping a ``MiddlewareEnvironment``
    ///   to an ``Effect``. Lazily evaluated — runs only when the ``Store`` triggers phase 3.
    public init(
        _ fn: @escaping @MainActor @Sendable (
            MiddlewareEnvironment<Environment, State>
        ) -> Effect<Action>
    ) {
        run = fn
    }

    // MARK: - Factories

    /// A reader that ignores the context and produces no effect.
    public static var doNothing: Self {
        MiddlewareReader { _ in .empty }
    }
}

// MARK: - Functor (Action axis)

extension MiddlewareReader {
    /// Maps every produced action through `f`, changing the `Action` type.
    ///
    /// ```swift
    /// let local: MiddlewareReader<LocalAction, E, S> = ...
    /// let global = local.map(AppAction.local)  // MiddlewareReader<AppAction, E, S>
    /// ```
    ///
    /// - Parameter f: A `@Sendable` transformation from `Action` to `GlobalAction`.
    /// - Returns: A `MiddlewareReader<GlobalAction, Environment, State>` whose effect maps
    ///   each dispatched action through `f`.
    public func map<GlobalAction: Sendable>(
        _ f: @escaping @Sendable (Action) -> GlobalAction
    ) -> MiddlewareReader<GlobalAction, Environment, State> {
        MiddlewareReader<GlobalAction, Environment, State> { ctx in self.run(ctx).map(f) }
    }
}

// MARK: - Contravariant (Environment axis)

extension MiddlewareReader {
    /// Projects the environment axis: the returned reader accepts a `GlobalEnvironment` and
    /// narrows it to `Environment` before running.
    ///
    /// ```swift
    /// let local: MiddlewareReader<A, AuthEnvironment, S> = ...
    /// let global = local.contramapEnvironment { (ge: AppEnvironment) in ge.auth }
    /// // MiddlewareReader<A, AppEnvironment, S>
    /// ```
    ///
    /// - Parameter f: A `@Sendable` projection from `GlobalEnvironment` to `Environment`.
    /// - Returns: A `MiddlewareReader<Action, GlobalEnvironment, State>`.
    public func contramapEnvironment<GlobalEnvironment: Sendable>(
        _ f: @escaping @Sendable (GlobalEnvironment) -> Environment
    ) -> MiddlewareReader<Action, GlobalEnvironment, State> {
        MiddlewareReader<Action, GlobalEnvironment, State> { ctx in
            self.run(MiddlewareEnvironment(
                environment: f(ctx.environment),
                stateAccess: ctx.stateAccess
            ))
        }
    }
}

// MARK: - State axis lifting

extension MiddlewareReader {
    /// Lifts the state axis using a total projection from `GlobalState` to `State`.
    ///
    /// ```swift
    /// let local: MiddlewareReader<A, E, AuthState> = ...
    /// let global = local.liftState { (gs: AppState) in gs.auth }
    /// // MiddlewareReader<A, E, AppState>
    /// ```
    ///
    /// - Parameter f: A `@MainActor @Sendable` closure from `GlobalState` to `State`.
    /// - Returns: A `MiddlewareReader<Action, Environment, GlobalState>`.
    public func liftState<GlobalState: Sendable>(
        _ f: @escaping @MainActor @Sendable (GlobalState) -> State
    ) -> MiddlewareReader<Action, Environment, GlobalState> {
        MiddlewareReader<Action, Environment, GlobalState> { ctx in
            self.run(MiddlewareEnvironment(
                environment: ctx.environment,
                stateAccess: { ctx.stateAccess().map(f) }
            ))
        }
    }

    /// Lifts the state axis using a partial projection from `GlobalState` to `State?`.
    ///
    /// Returns `nil` state when the projection returns `nil` (e.g., the focused enum case is
    /// absent). Middleware that calls `ctx.stateAccess()` inside will receive `nil` in that case
    /// and should treat it as "no state available — skip the effect".
    ///
    /// ```swift
    /// let local: MiddlewareReader<A, E, AuthState> = ...
    /// let global = local.liftState { (gs: AppState) in gs.authenticatedUser }
    /// // MiddlewareReader<A, E, AppState> — stateAccess() is nil when user is nil
    /// ```
    ///
    /// - Parameter f: A `@MainActor @Sendable` partial projection from `GlobalState` to `State?`.
    /// - Returns: A `MiddlewareReader<Action, Environment, GlobalState>`.
    public func liftState<GlobalState: Sendable>(
        _ f: @escaping @MainActor @Sendable (GlobalState) -> State?
    ) -> MiddlewareReader<Action, Environment, GlobalState> {
        MiddlewareReader<Action, Environment, GlobalState> { ctx in
            self.run(MiddlewareEnvironment(
                environment: ctx.environment,
                stateAccess: { ctx.stateAccess().flatMap(f) }
            ))
        }
    }
}

// MARK: - Semigroup & Monoid

extension MiddlewareReader: Semigroup {
    /// Combines two readers: both receive the same `MiddlewareEnvironment`; their effects
    /// are merged via ``Effect/combine(_:_:)`` and run concurrently.
    ///
    /// - Parameters:
    ///   - lhs: The first reader.
    ///   - rhs: The second reader.
    /// - Returns: A reader whose effect is the parallel combination of both inputs.
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        MiddlewareReader { ctx in .combine(lhs.run(ctx), rhs.run(ctx)) }
    }
}

extension MiddlewareReader: Monoid {
    /// The no-op reader — ignores every context and produces no effect.
    ///
    /// Equivalent to ``doNothing``. Acts as the identity element for ``combine(_:_:)``.
    public static var identity: Self { .doNothing }
}
