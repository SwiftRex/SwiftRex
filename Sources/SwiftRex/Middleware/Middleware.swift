import CoreFP
import DataStructure

/// Observes dispatched actions and produces side effects without mutating state.
///
/// `Middleware` is the pure, side-effect-producing half of a feature's logic. It receives every
/// dispatched action together with a ``PreReducerContext`` giving read-only access to the current
/// (pre-mutation) state, and returns a
/// `Reader<PostReducerContext<State, Environment>, Effect<Action>>` — a deferred computation the
/// ``Store`` will run in phase 3 of dispatch, after all state mutations have completed.
///
/// ```
/// dispatch    Middleware.handle                   Reader.runReader(postCtx) (phase 3)
///    │               │                                       │
///    ▼               ▼                                       ▼
/// Action ──► context.stateBefore = pre-mutation   ctx.liveState = current (post-mutation)
///                     └──► Reader<PostReducerContext, Effect<Action>>
///                                     └──► postCtx injected by Store at phase 3
/// ```
///
/// ## Pre- and post-mutation state
///
/// Use ``PreReducerContext/stateBefore`` in phase 1 and ``PostReducerContext/liveState`` (or
/// the `readLiveState()` helper from `SwiftRex.Combine`, `SwiftRex.RxSwift`, or
/// `SwiftRex.ReactiveSwift`) in the returned `Reader`. Read synchronously there, `liveState`
/// is this cycle's post-mutation state; read later from an async effect, it is the Store's
/// current state at that moment:
///
/// ```swift
/// Middleware<MyAction, MyState, MyEnvironment>.handle { action, context in
///     let pre = context.stateBefore    // pre-mutation state (phase 1)
///
///     return Reader { ctx in
///         // ctx.liveState — post-mutation state when read here (phase 3, @MainActor)
///         return .just(.log(before: pre))
///     }
/// }
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
/// middleware read `context.stateBefore` directly (also `@MainActor`) in phase 1.
///
/// ## Middleware is stateless
///
/// `Middleware` holds no instance state. Patterns that seem to require state — debouncing,
/// throttling, tracking in-flight requests — are expressed as ``EffectScheduling`` directives
/// on the returned ``Effect``.
///
/// ## Composition
///
/// `Middleware` is a **Semigroup** and **Monoid**. ``combine(_:_:)`` gives both middlewares the
/// same action and context; their effects are merged via ``Effect/combine(_:_:)`` and run
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
    /// The core function: given an action and a pre-mutation context, returns a deferred
    /// `Reader<PostReducerContext<State, Environment>, Effect<Action>>` that the Store will
    /// run in phase 3 (post-mutation).
    ///
    /// - **Phase 1**: Called with `context` reflecting the current (pre-mutation) state.
    /// - **Phase 3**: The returned `Reader` is run with a ``PostReducerContext`` that gives
    ///   access to `environment` and `liveState` (this cycle's post-mutation state when read here).
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here.
    public let handle: @MainActor @Sendable (
        _ action: Action,
        _ context: PreReducerContext<State>
    ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>

    /// Creates a `Middleware` from a `handle` closure.
    ///
    /// - Parameter handle: The closure mapping `(Action, PreReducerContext<State>)` to a
    ///   `Reader<PostReducerContext<State, Environment>, Effect<Action>>`.
    ///   Called on `@MainActor` during phase 1.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
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
    /// let myMiddleware = Middleware<AppAction, AppState, AppEnvironment>.handle { action, context in
    ///     Reader { ctx in ... }
    /// }
    /// ```
    ///
    /// - Parameter fn: The handle closure.
    /// - Returns: A `Middleware` wrapping `fn`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self { Middleware(handle: fn) }
}

// MARK: - Semigroup & Monoid

extension Middleware: Semigroup {
    /// Combines two middlewares: both see the same action and pre-mutation context; their
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
        Middleware { action, context in
            // Capture both readers on @MainActor in phase 1; the combined Reader
            // then calls both lazily in phase 3 — no eager effect evaluation.
            let lhsReader = lhs.handle(action, context)
            let rhsReader = rhs.handle(action, context)
            return Reader { ctx in .combine(lhsReader.runReader(ctx), rhsReader.runReader(ctx)) }
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
