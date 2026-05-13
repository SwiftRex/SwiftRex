import CoreFP
import DataStructure

/// The primary composition unit: a pure description of how a feature responds to actions.
///
/// Handles every action in three globally-ordered phases managed by the Store:
///
/// ```
/// Phase 1  handle(action, stateAccess)      all Behaviors — stateAccess = pre-mutation state
/// Phase 2  mutation.runEndoMut(&_state)      all EndoMuts  — zero-copy inout
/// Phase 3  effect.runReader(environment)     all Readers   — stateAccess = post-mutation state
/// ```
///
/// Because phase 1 runs before any mutation, a Logger `Behavior` can read genuine pre-mutation
/// state via `stateAccess.snapshotState()` and genuine post-mutation state inside its
/// `produce` closure — both through the same reference, different moments.
///
/// ## Creation
///
/// ```swift
/// // Full form — access to pre-mutation state
/// let loggerBehavior = Behavior<Action, AppState, AppEnvironment> { action, stateAccess in
///     let before = stateAccess.snapshotState()
///     return .produce { _ in
///         .fireAndForget { log(action, before, stateAccess.snapshotState()) }
///     }
/// }
///
/// // Simple form via Reducer
/// let counterBehavior = counterReducer.asBehavior()
///
/// // Combined
/// let authBehavior = Behavior(reducer: authReducer, middleware: authMiddleware)
/// ```
public struct Behavior<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    public let handle: @MainActor @Sendable (
        _ action: DispatchedAction<Action>,
        _ state: StateAccess<State>
    ) -> Consequence<State, Environment, Action>

    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Consequence<State, Environment, Action>
    ) {
        self.handle = handle
    }
}

// MARK: - Named constructors

extension Behavior {
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Consequence<State, Environment, Action>
    ) -> Self { Behavior(handle: fn) }
}

// MARK: - Reducer + Middleware

extension Behavior {
    /// Combines a `Reducer` and a `Middleware` into a single `Behavior`.
    ///
    /// The reducer provides the `EndoMut` (phase 2), the middleware provides the
    /// `Reader` (phase 3). Both are composed without any state copies.
    public init(
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, State, Environment>
    ) {
        self.handle = { action, stateAccess in
            Consequence(
                mutation: reducer.reduce(action.action),
                effect: middleware.handle(action, stateAccess)
            )
        }
    }
}

// MARK: - Semigroup & Monoid

extension Behavior: Semigroup {
    /// Parallel composition: both handle closures run in phase 1 with the same pre-mutation
    /// state; their `EndoMut`s compose sequentially (lhs then rhs); their effects run in parallel.
    public static func combine(_ lhs: Behavior, _ rhs: Behavior) -> Behavior {
        Behavior { action, stateAccess in
            .combine(lhs.handle(action, stateAccess), rhs.handle(action, stateAccess))
        }
    }
}

extension Behavior: Monoid {
    public static var identity: Behavior {
        Behavior { _, _ in .doNothing }
    }
}
