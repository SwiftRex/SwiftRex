import CoreFP
import DataStructure

/// Observes dispatched actions and produces side effects without mutating state.
///
/// `Middleware` is the pure, side-effect-producing half of a feature's logic. It receives every
/// dispatched action together with a lazy read-only view of the current state, and returns a
/// ``MiddlewareReader`` — a `@MainActor`-isolated deferred computation that the ``Store`` will
/// run in phase 3 of dispatch, after all state mutations have completed.
///
/// ```
/// dispatch          Middleware.handle                  MiddlewareReader.run (phase 3)
///    │                    │                                    │
///    ▼                    ▼                                    ▼
/// Action ──► stateAccess.snapshotState() = pre-mutation    ctx.stateAccess() = post-mutation
///                          └──► MiddlewareReader<Action, Environment, State>
///                                         └──► ctx.environment + ctx.stateAccess injected by Store
/// ```
///
/// ## Single action type
///
/// `Middleware<Action, State, Environment>` uses a single `Action` type for both incoming and
/// outgoing actions. To narrow the action scope, use ``liftAction(_:)`` with a `Prism` — actions
/// not matched by the prism are silently ignored, and produced actions are wrapped through the
/// prism's `review` function before re-entering the Store.
///
/// ## Always @MainActor
///
/// The ``Store`` is `@MainActor`, so `handle` is always called on the main actor. This lets
/// middleware call `stateAccess.snapshotState()` directly (also `@MainActor`) and keeps state
/// reads safe by construction, with no manual actor-hopping required.
///
/// The returned ``MiddlewareReader`` is also `@MainActor`, so `ctx.stateAccess()` inside the
/// reader's closure likewise needs no `assumeIsolated` workaround.
///
/// ## Middleware is stateless
///
/// `Middleware` holds no instance state. Patterns that seem to require state — debouncing,
/// throttling, keeping track of in-flight requests — are expressed as ``EffectScheduling``
/// directives on the returned ``Effect``. The Store manages all lifecycle state.
///
/// ```swift
/// // Debounce without instance state on the middleware
/// Middleware<SearchAction, SearchState, SearchEnvironment>.handle { action, _ in
///     guard case .queryChanged(let q) = action.action else {
///         return MiddlewareReader { _ in .empty }
///     }
///     return MiddlewareReader { ctx in
///         ctx.environment.api.search(q).asEffect()
///             .scheduling(.debounce(id: "search", delay: 0.3))
///     }
/// }
/// ```
///
/// ## Pre- and post-mutation state
///
/// The same `StateAccess` reference yields different values depending on when it is called.
/// Additionally, `ctx.stateAccess()` inside the ``MiddlewareReader`` always reflects
/// post-mutation state (phase 3):
///
/// ```swift
/// Middleware<MyAction, MyState, MyEnvironment>.handle { action, stateAccess in
///     let pre = stateAccess.snapshotState()    // pre-mutation state (phase 1)
///
///     return MiddlewareReader { ctx in
///         let post = ctx.stateAccess()         // post-mutation state (phase 3)
///         return .just(.log(before: pre, after: post))
///     }
/// }
/// ```
///
/// ## Composition
///
/// `Middleware` is a **Semigroup** and **Monoid**. ``combine(_:_:)`` gives both middlewares the
/// same action and state access; their effects are merged via ``Effect/combine(_:_:)`` and run
/// concurrently. Order does not affect what each middleware observes.
///
/// ## Lifting
///
/// Feature middlewares operate on local types. Use the lift family to embed them in the app's
/// global types:
///
/// - ``liftAction(_:)`` — narrows via a `Prism`
/// - ``liftState(_:)-9kjxz`` — widens via a getter closure
/// - ``liftState(_:)-5j4jz`` — widens via a `Lens`
/// - ``liftState(_:)-3cpnb`` — widens via a `Prism` (optional enum state)
/// - ``liftState(_:)-4f8n1`` — widens via an `AffineTraversal`
/// - ``liftEnvironment(_:)`` — narrows via a projection closure
/// - ``lift(action:state:environment:)-5ttmj`` and overloads — all three axes at once
public struct Middleware<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    /// The core function: given a dispatched action and lazy state access, returns a deferred
    /// ``MiddlewareReader`` that the Store will run in phase 3 (post-mutation) to obtain the
    /// ``Effect``.
    ///
    /// - **Phase 1**: Called with `state` reflecting the current (pre-mutation) state.
    /// - **Phase 3**: The returned ``MiddlewareReader`` is run; `ctx.stateAccess()` yields
    ///   post-mutation state. Because the reader's closure is `@MainActor`, calling
    ///   `ctx.stateAccess()` needs no `assumeIsolated`.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here.
    public let handle: @MainActor @Sendable (
        _ action: DispatchedAction<Action>,
        _ state: StateAccess<State>
    ) -> MiddlewareReader<Action, Environment, State>

    /// Creates a `Middleware` from a `handle` closure.
    ///
    /// - Parameter handle: The closure mapping `(DispatchedAction, StateAccess)` to a
    ///   ``MiddlewareReader``. Called on `@MainActor` during phase 1.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> MiddlewareReader<Action, Environment, State>
    ) {
        self.handle = handle
    }
}

// MARK: - Named constructors

extension Middleware {
    /// Named constructor — equivalent to `Middleware(handle:)` but reads more naturally
    /// at the call site:
    ///
    /// ```swift
    /// let myMiddleware = Middleware<AppAction, AppState, AppEnvironment>.handle { action, state in
    ///     // return a MiddlewareReader<AppAction, AppEnvironment, AppState>
    /// }
    /// ```
    ///
    /// - Parameter fn: The handle closure.
    /// - Returns: A `Middleware` wrapping `fn`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> MiddlewareReader<Action, Environment, State>
    ) -> Self { Middleware(handle: fn) }

    /// Convenience constructor for middlewares that do not need the environment.
    ///
    /// When `Environment == Void`, the middleware's effect does not depend on any injected
    /// dependency. This overload avoids the boilerplate of constructing a ``MiddlewareReader``
    /// manually — the closure may return an ``Effect`` directly:
    ///
    /// ```swift
    /// // No environment needed — return Effect directly
    /// let loggingMiddleware = Middleware<AppAction, AppState, Void>.handle { action, _ in
    ///     print("Action dispatched:", action.action)
    ///     return .empty
    /// }
    /// ```
    ///
    /// - Parameter fn: A closure that returns an ``Effect`` directly (not wrapped in a
    ///   ``MiddlewareReader``). Evaluated lazily in phase 3.
    /// - Returns: A `Middleware` that wraps `fn` in a ``MiddlewareReader``.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Effect<Action>
    ) -> Self where Environment == Void {
        Middleware { action, state in
            MiddlewareReader { _ in fn(action, state) }
        }
    }
}

// MARK: - Semigroup & Monoid

extension Middleware: Semigroup {
    /// Combines two middlewares: both see the same action and pre-mutation state; their
    /// effects are merged via ``Effect/combine(_:_:)`` and run concurrently.
    ///
    /// ```swift
    /// let combined = Middleware.combine(analyticsMiddleware, networkMiddleware)
    /// ```
    ///
    /// - Parameters:
    ///   - lhs: The first middleware.
    ///   - rhs: The second middleware.
    /// - Returns: A middleware whose effect is the parallel combination of both inputs.
    public static func combine(_ lhs: Middleware, _ rhs: Middleware) -> Middleware {
        Middleware { action, state in
            // Capture both readers on @MainActor in phase 1; the combined MiddlewareReader
            // then calls both lazily in phase 3 — no eager effect evaluation.
            let lhsReader = lhs.handle(action, state)
            let rhsReader = rhs.handle(action, state)
            return MiddlewareReader { ctx in
                .combine(lhsReader.run(ctx), rhsReader.run(ctx))
            }
        }
    }
}

extension Middleware: Monoid {
    /// The no-op middleware — ignores every action and produces no effects.
    ///
    /// Acts as the identity element for ``combine(_:_:)``.
    public static var identity: Middleware {
        Middleware { _, _ in MiddlewareReader { _ in .empty } }
    }
}
