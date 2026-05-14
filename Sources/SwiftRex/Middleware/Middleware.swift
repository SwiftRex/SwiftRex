import CoreFP
import DataStructure

/// Observes dispatched actions and produces side effects without mutating state.
///
/// `Middleware` is the pure, side-effect-producing half of a feature's logic. It receives every
/// dispatched action together with a lazy read-only view of the current state, and returns a
/// `Reader<Environment, Effect<Action>>` — a deferred effect that the ``Store`` will schedule in
/// phase 3 of dispatch, after all state mutations have completed.
///
/// ```
/// dispatch         Middleware.handle                 Reader runs (phase 3, post-mutation)
///    │                    │                                    │
///    ▼                    ▼                                    ▼
/// Action ──► state.snapshotState() = pre-mutation    state.snapshotState() = post-mutation
///                          └──► Reader<Environment, Effect<Action>>
///                                         └──► environment injected by Store
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
/// ## Middleware is stateless
///
/// `Middleware` holds no instance state. Patterns that seem to require state — debouncing,
/// throttling, keeping track of in-flight requests — are expressed as ``EffectScheduling``
/// directives on the returned ``Effect``. The Store manages all lifecycle state.
///
/// ```swift
/// // Debounce without instance state on the middleware
/// Middleware<SearchAction, SearchState, SearchEnvironment> { action, _ in
///     guard case .queryChanged(let q) = action.action else {
///         return Reader { _ in .empty }
///     }
///     return Reader { env in
///         env.api.search(q).asEffect()
///             .scheduling(.debounce(id: "search", delay: 0.3))
///     }
/// }
/// ```
///
/// ## Pre- and post-mutation state
///
/// The same `StateAccess` reference yields different values depending on when it is called:
///
/// ```swift
/// Middleware<MyAction, MyState, MyEnvironment> { action, state in
///     let pre = state.snapshotState()    // pre-mutation state (phase 1)
///
///     return Reader { env in
///         let post = state.snapshotState()  // post-mutation state (phase 3)
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
    /// `Reader` that the Store will run in phase 3 (post-mutation) to obtain the ``Effect``.
    ///
    /// - **Phase 1**: Called with `state` reflecting the current (pre-mutation) state.
    /// - **Phase 3**: The returned `Reader` is run with the environment after all mutations
    ///   complete; at that point `state.snapshotState()` yields post-mutation state.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here.
    public let handle: @MainActor @Sendable (
        _ action: DispatchedAction<Action>,
        _ state: StateAccess<State>
    ) -> Reader<Environment, Effect<Action>>

    /// Creates a `Middleware` from a `handle` closure.
    ///
    /// - Parameter handle: The closure mapping `(DispatchedAction, StateAccess)` to a
    ///   `Reader<Environment, Effect<Action>>`. Called on `@MainActor` during phase 1.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Reader<Environment, Effect<Action>>
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
    ///     // return a Reader<AppEnvironment, Effect<AppAction>>
    /// }
    /// ```
    ///
    /// - Parameter fn: The handle closure.
    /// - Returns: A `Middleware` wrapping `fn`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Reader<Environment, Effect<Action>>
    ) -> Self { Middleware(handle: fn) }

    /// Convenience constructor for middlewares that do not need the environment.
    ///
    /// When `Environment == Void`, the middleware's effect does not depend on any injected
    /// dependency. This overload avoids the boilerplate of wrapping the result in a `Reader`:
    ///
    /// ```swift
    /// // No environment needed — return Effect directly
    /// let loggingMiddleware = Middleware<AppAction, AppState, Void>.handle { action, _ in
    ///     print("Action dispatched:", action.action)
    ///     return .empty
    /// }
    /// ```
    ///
    /// - Parameter fn: A closure that returns an ``Effect`` directly (not wrapped in a `Reader`).
    /// - Returns: A `Middleware` that wraps `fn`'s result in `Reader { _ in ... }`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Effect<Action>
    ) -> Self where Environment == Void {
        Middleware { action, state in Reader { _ in fn(action, state) } }
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
            Reader { env in
                .combine(
                    lhs.handle(action, state).runReader(env),
                    rhs.handle(action, state).runReader(env)
                )
            }
        }
    }
}

extension Middleware: Monoid {
    /// The no-op middleware — ignores every action and produces no effects.
    ///
    /// Acts as the identity element for ``combine(_:_:)``.
    public static var identity: Middleware {
        Middleware { _, _ in Reader { _ in .empty } }
    }
}
