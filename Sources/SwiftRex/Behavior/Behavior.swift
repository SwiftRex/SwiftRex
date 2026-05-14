import CoreFP
import DataStructure

/// The primary composition unit: a pure description of how a feature responds to actions.
///
/// `Behavior` is the top-level abstraction for feature logic in SwiftRex. It combines the
/// responsibilities of ``Reducer`` (state mutation) and ``Middleware`` (side effects) into a
/// single closure, making it easy to keep related logic together without splitting it across
/// two separate types.
///
/// ## Three-phase dispatch
///
/// When the ``Store`` receives an action, it processes all `Behavior` values in three globally
/// ordered phases:
///
/// ```
/// Phase 1  behavior.handle(action, stateAccess)   — all Behaviors, pre-mutation state
/// Phase 2  consequence.mutation.runEndoMut(&state) — all mutations, zero-copy inout
/// Phase 3  consequence.effect.runReader(env)       — all effects, post-mutation state
/// ```
///
/// Because every `Behavior.handle` call in phase 1 sees the same pre-mutation state, composing
/// two behaviors with ``combine(_:_:)`` gives them identical views of the world — neither
/// behavior's logic can depend on the other's mutations.
///
/// ## Creating a Behavior
///
/// The full closure form gives access to both the dispatched action and a lazy state view:
///
/// ```swift
/// // Full form — pre/post state access, environment injection in produce
/// let loggerBehavior = Behavior<AppAction, AppState, AppEnvironment> { action, stateAccess in
///     let before = stateAccess.snapshotState()
///     return .produce { _ in
///         .just(.log(action: action.action, before: before, after: stateAccess.snapshotState()))
///     }
/// }
///
/// // From a Reducer — no side effects
/// let counterBehavior = counterReducer.asBehavior()
///
/// // From a Reducer and a Middleware together
/// let authBehavior = Behavior(reducer: authReducer, middleware: authMiddleware)
/// ```
///
/// ## Composition
///
/// `Behavior` is a **Semigroup** and **Monoid**. Combining two behaviors runs both in phase 1
/// (same pre-mutation state), sequences their mutations (lhs then rhs), and runs their effects
/// concurrently:
///
/// ```swift
/// // Build the complete app behavior from module behaviors
/// let appBehavior = Behavior.combine(
///     authBehavior.lift(action: AppAction.prism.auth, state: \.auth, environment: \.auth),
///     profileBehavior.lift(action: AppAction.prism.profile, state: \.profile, environment: \.profile)
/// )
/// ```
///
/// ## Lifting
///
/// Feature behaviors operate on local types. Use the lift family to embed them in the app's
/// global types without changing their logic:
///
/// - ``liftAction(_:)`` — narrows via a `Prism` (enum case)
/// - ``liftState(_:)-7bmm8`` — widens via `WritableKeyPath`
/// - ``liftState(_:)-7r4jg`` — widens via `Lens`
/// - ``liftState(_:)-4hwa6`` — widens via `Prism` (optional enum state)
/// - ``liftState(_:)-8tflj`` — widens via `AffineTraversal`
/// - ``liftEnvironment(_:)`` — narrows via a projection closure
/// - ``lift(action:state:environment:)-9azuf`` and overloads — all three axes at once
///
/// - Note: `Behavior.handle` is `@MainActor`. The ``Store`` calls it on the main actor,
///   so `stateAccess.snapshotState()` is always safe to call directly inside the closure.
public struct Behavior<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    /// The core function: given a dispatched action and lazy state access, returns the
    /// complete consequence (mutation + effect) for this action.
    ///
    /// - **Phase 1**: Called with `stateAccess` reflecting the current (pre-mutation) state.
    /// - The returned ``Consequence`` is applied by the Store in phases 2 and 3.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here — move
    ///   async work into the returned ``Consequence/produce(_:)`` closure.
    public let handle: @MainActor @Sendable (
        _ action: DispatchedAction<Action>,
        _ state: StateAccess<State>
    ) -> Consequence<State, Environment, Action>

    /// Creates a `Behavior` from a `handle` closure.
    ///
    /// - Parameter handle: The closure that maps `(DispatchedAction<Action>, StateAccess<State>)`
    ///   to ``Consequence``. Called on `@MainActor` by the Store during phase 1.
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
    /// Named constructor — equivalent to `Behavior(handle:)` but reads more naturally
    /// at the call site:
    ///
    /// ```swift
    /// let myBehavior = Behavior<AppAction, AppState, AppEnvironment>.handle { action, state in
    ///     // ...
    /// }
    /// ```
    ///
    /// - Parameter fn: The handle closure.
    /// - Returns: A `Behavior` wrapping `fn`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: DispatchedAction<Action>,
            _ state: StateAccess<State>
        ) -> Consequence<State, Environment, Action>
    ) -> Self { Behavior(handle: fn) }
}

// MARK: - Reducer + Middleware

extension Behavior {
    /// Creates a `Behavior` by pairing a ``Reducer`` with a ``Middleware``.
    ///
    /// The reducer provides the `EndoMut` (phase 2 mutation) and the middleware provides the
    /// `Reader<Environment, Effect<Action>>` (phase 3 effect). Both are composed into a
    /// ``Consequence`` without any intermediate state copies.
    ///
    /// Use this when you already have separate reducer and middleware values and want to
    /// combine them into one unit for a feature:
    ///
    /// ```swift
    /// let authBehavior = Behavior(
    ///     reducer: authReducer,
    ///     middleware: authMiddleware
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - reducer: Handles state mutation for the feature. Called for every action.
    ///   - middleware: Handles side effects for the feature. Sees pre-mutation state via
    ///     `StateAccess` during its `handle` call and post-mutation state inside the returned
    ///     `Reader`.
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
    /// Combines two behaviors: both handle closures run in phase 1 with the same pre-mutation
    /// state; their mutations compose sequentially (lhs then rhs); their effects run in parallel.
    ///
    /// This is the building block for assembling app-level behavior from feature modules:
    ///
    /// ```swift
    /// let appBehavior = Behavior.combine(
    ///     authBehavior.lift(action: AppAction.prism.auth, state: \.auth, environment: \.auth),
    ///     profileBehavior.lift(action: AppAction.prism.profile, state: \.profile, environment: \.profile)
    /// )
    /// ```
    ///
    /// - Important: Both `lhs.handle` and `rhs.handle` see identical pre-mutation state.
    ///   The sequential ordering only applies to the `EndoMut` values in phase 2, not to what
    ///   each handle closure observes.
    ///
    /// - Parameters:
    ///   - lhs: The first behavior; its mutation runs first.
    ///   - rhs: The second behavior; its mutation sees lhs's mutations.
    /// - Returns: A combined behavior that runs both handle closures and merges their consequences.
    public static func combine(_ lhs: Behavior, _ rhs: Behavior) -> Behavior {
        Behavior { action, stateAccess in
            .combine(lhs.handle(action, stateAccess), rhs.handle(action, stateAccess))
        }
    }
}

extension Behavior: Monoid {
    /// The no-op behavior — ignores every action, produces no mutations and no effects.
    ///
    /// Acts as the identity element for ``combine(_:_:)``:
    /// `combine(b, identity) == combine(identity, b) == b` for any behavior `b`.
    public static var identity: Behavior {
        Behavior { _, _ in .doNothing }
    }
}
