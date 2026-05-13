import CoreFP
import DataStructure

/// Observes dispatched actions and produces effects without mutating state.
///
/// ```
/// dispatch         Middleware.handle                 Reader runs (post-reducer)
///    │                    │                                    │
///    ▼                    ▼                                    ▼
/// Action ──► state.snapshotState() = pre-reducer    state.snapshotState() = post-reducer
///                          └──► Reader<Environment, Effect<Action>>
///                                         └──► env injected by Store
/// ```
///
/// **Single action type.** `Middleware<Action, State, Environment>` — the same `Action`
/// type flows in and out. Lifting uses a `Prism` for both directions simultaneously.
///
/// **Always `@MainActor`.** The Store is `@MainActor`, so `handle` is always called on the
/// main actor. This lets middleware call `StateAccess.snapshotState()` (also `@MainActor`)
/// directly and keeps state access safe by construction.
///
/// **Middleware is pure.** No instance state. Debounce, throttle, and cancellation are
/// expressed as `EffectScheduling` directives and managed by the Store.
public struct Middleware<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    public let handle: @MainActor @Sendable (
        _ action: DispatchedAction<Action>,
        _ state: StateAccess<State>
    ) -> Reader<Environment, Effect<Action>>

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
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Reader<Environment, Effect<Action>>
    ) -> Self { Middleware(handle: fn) }

    /// Convenience when the environment is not needed.
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
    /// Parallel composition: both middlewares see the same action and state;
    /// their effects are merged via `Effect.combine` (run concurrently by the Store).
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
    /// The no-op middleware — ignores every action, produces no effects.
    public static var identity: Middleware {
        Middleware { _, _ in Reader { _ in .empty } }
    }
}
