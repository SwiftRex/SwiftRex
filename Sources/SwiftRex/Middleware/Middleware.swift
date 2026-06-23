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
/// - ``liftState(_:)`` — widens via a getter closure
/// - ``liftState(_:)`` — widens via a `Lens`
/// - ``liftState(_:)`` — widens via a `Prism` (optional enum state)
/// - ``liftState(_:)`` — widens via an `AffineTraversal`
/// - ``liftEnvironment(_:)`` — narrows via a projection closure
/// - ``lift(action:state:environment:)`` and overloads — all three axes at once
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
    ) -> Reaction<Action, State, Environment>

    /// The **state** side: given the post-mutation state, the complete set of ``Channel``s that should
    /// be alive (Elm's `Sub`) — or `nil` when the middleware has **no** `supervise`. Reconciled by the
    /// Store after every change; ``combine(_:_:)`` unions it. Build it with ``supervise(_:)``.
    package let supervisor: (@MainActor @Sendable (_ state: State) -> Keep<Action, Environment>)?

    /// Whether this middleware has **any** `supervise` (the state-driven axis) — *derived* from the
    /// presence of a supervisor, never a separate flag that can drift (like `isEmpty` from `count`).
    /// The ``Store`` reconciles only when this is `true`, so a non-supervising middleware is a true
    /// bypass (phase 5 reads no state).
    package var supervises: Bool { supervisor != nil }

    /// Creates a `Middleware` from a `handle` closure and an optional `supervisor`. Providing a
    /// supervisor means it supervises (the Store reconciles its channels); omitting it (`nil`) means it
    /// never does — so the flag can't desync from reality.
    ///
    /// - Parameters:
    ///   - handle: Maps `(Action, PreReducerContext)` to a ``Reaction`` (the action side).
    ///   - supervisor: Maps state to the channels to keep alive (the state side), or `nil` for none.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reaction<Action, State, Environment>,
        supervisor: (@MainActor @Sendable (State) -> Keep<Action, Environment>)? = nil
    ) {
        self.handle = handle
        self.supervisor = supervisor
    }
}

extension Middleware {
    /// Creates an **action-driven** middleware — the `react` (Cmd) side. Equivalent to `Middleware(handle:)`.
    public static func react(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    ) -> Self { Middleware(handle: fn) }

    /// Creates a **state-driven** middleware — the `supervise` (Sub) side, handling no actions.
    ///
    /// ```swift
    /// let socketMiddleware = Middleware<A, S, Env>.supervise { state in
    ///     Keep { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
    /// }
    /// ```
    public static func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Keep<Action, Environment>
    ) -> Self {
        Middleware(handle: { _, _ in Reader { _ in .empty } }, supervisor: keep)
    }

    /// Adds an effect concern, combining it with `self` — `m.react { … }` ≡ `m <> .react { … }`.
    public func react(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    ) -> Self { .combine(self, .react(fn)) }

    /// Adds a state-driven concern, combining it with `self` — `m.supervise { … }` ≡ `m <> .supervise { … }`.
    public func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Keep<Action, Environment>
    ) -> Self { .combine(self, .supervise(keep)) }
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
        Middleware(
            handle: { action, context in
                // Capture both readers on @MainActor in phase 1; the combined Reader
                // then calls both lazily in phase 3 — no eager effect evaluation.
                let lhsReader = lhs.handle(action, context)
                let rhsReader = rhs.handle(action, context)
                return Reader { ctx in .combine(lhsReader.runReader(ctx), rhsReader.runReader(ctx)) }
            },
            supervisor: Middleware.unionSupervise([lhs, rhs])
        )
    }

    /// Unions the `supervise` axes — `nil` when **none** of `middlewares` supervise (so a fully
    /// non-supervising composition stays a true bypass); otherwise resolves only the supervising ones.
    static func unionSupervise(
        _ middlewares: [Middleware]
    ) -> (@MainActor @Sendable (State) -> Keep<Action, Environment>)? {
        let supervisors = middlewares.compactMap(\.supervisor)
        guard !supervisors.isEmpty else { return nil }
        return { @MainActor state in
            let keeps = supervisors.map { $0(state) }
            return Reader { env in keeps.flatMap { $0.runReader(env) } }
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
