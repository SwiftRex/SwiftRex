#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
import SwiftRex

/// The wiring that scopes a child feature into a parent (app) store — declared **once** and reused
/// by both behavior composition and (in a later stage) navigation.
///
/// A `Scope` captures how a child feature's `(Action, State, Environment)` embeds into the parent's
/// `(GlobalAction, GlobalState, GlobalEnvironment)`: the action prism, the state key path, and the
/// environment-narrowing closure. From those it derives the child's **lifted behavior**
/// (``lifted``), typed at the global types so a whole app's behaviors are homogeneous and fold with
/// the ``Behavior`` monoid.
///
/// ## Compile-time proof of wiring
///
/// Constructing a `Scope` *is* the proof the feature is wired: the initializer will not type-check
/// unless the global state slot, global action case (prism), environment-narrowing, and the child's
/// own `(Action, State, Environment)` all exist and line up. Forget the slot, the case, or the
/// env-narrowing and you get a **compile error at the `Scope` literal** — not a silent missing
/// screen at runtime.
///
/// ```swift
/// let homeScope = Scope(
///     behavior:    HomeFeature.behavior(),
///     action:      \.home,          // PrismKeyPath<AppAction, HomeFeature.Action>
///     state:       \.home,          // WritableKeyPath<AppState, HomeFeature.State>
///     environment: \.homeEnv        // KeyPath<World, HomeFeature.Environment>
/// )
/// // homeScope.lifted : Behavior<AppAction, AppState, World>
/// ```
///
/// Register every scope's ``lifted`` behavior in one homogeneous list so you can't forget to
/// compose one:
///
/// ```swift
/// let appBehavior = Behavior.combine([homeScope.lifted, detailScope.lifted, navigationReducer])
/// ```
///
/// A scope over an **optional** child state (`ChildState?`) lifts with `liftOptional`, so the child
/// behavior runs only while its slice is `.some` — the shape a presented/pushed screen uses.
public struct Scope<GlobalAction: Sendable, GlobalState: Sendable, GlobalEnvironment: Sendable>: Sendable {
    /// The child behavior lifted to the global `(Action, State, Environment)` — homogeneous across
    /// every scope, so a whole app's behaviors fold with ``Behavior/combine(_:)-(Array)``.
    public let lifted: Behavior<GlobalAction, GlobalState, GlobalEnvironment>

    // MARK: - Always-present child state (env as closure)

    /// Scopes a child whose state is always present in the parent (a sibling slice — the shape used
    /// for tabs/split children that all stay alive).
    public init<ChildAction: Sendable, ChildState: Sendable, ChildEnvironment: Sendable>(
        behavior: Behavior<ChildAction, ChildState, ChildEnvironment>,
        action: PrismKeyPath<GlobalAction, ChildAction>,
        state: WritableKeyPath<GlobalState, ChildState>,
        environment: @escaping @Sendable (GlobalEnvironment) -> ChildEnvironment
    ) where GlobalAction: Prismatic {
        lifted = behavior.lift(action: action, state: state, environment: environment)
    }

    /// Env-as-key-path convenience for an always-present child.
    public init<ChildAction: Sendable, ChildState: Sendable, ChildEnvironment: Sendable>(
        behavior: Behavior<ChildAction, ChildState, ChildEnvironment>,
        action: PrismKeyPath<GlobalAction, ChildAction>,
        state: WritableKeyPath<GlobalState, ChildState>,
        environment: KeyPath<GlobalEnvironment, ChildEnvironment> & Sendable
    ) where GlobalAction: Prismatic {
        self.init(behavior: behavior, action: action, state: state, environment: { $0[keyPath: environment] })
    }

    // MARK: - Optional child state (present-while-.some)

    /// Scopes a child whose state is **optional** — the child behavior runs only while the slice is
    /// `.some` (the shape a presented sheet / pushed screen uses). Lifts with `liftOptional`.
    public init<ChildAction: Sendable, ChildState: Sendable, ChildEnvironment: Sendable>(
        behavior: Behavior<ChildAction, ChildState, ChildEnvironment>,
        action: PrismKeyPath<GlobalAction, ChildAction>,
        state: WritableKeyPath<GlobalState, ChildState?>,
        environment: @escaping @Sendable (GlobalEnvironment) -> ChildEnvironment
    ) where GlobalAction: Prismatic {
        lifted = behavior.liftOptional(action: action, state: state, environment: environment)
    }

    /// Env-as-key-path convenience for an optional child.
    public init<ChildAction: Sendable, ChildState: Sendable, ChildEnvironment: Sendable>(
        behavior: Behavior<ChildAction, ChildState, ChildEnvironment>,
        action: PrismKeyPath<GlobalAction, ChildAction>,
        state: WritableKeyPath<GlobalState, ChildState?>,
        environment: KeyPath<GlobalEnvironment, ChildEnvironment> & Sendable
    ) where GlobalAction: Prismatic {
        self.init(behavior: behavior, action: action, state: state, environment: { $0[keyPath: environment] })
    }
}
#endif
