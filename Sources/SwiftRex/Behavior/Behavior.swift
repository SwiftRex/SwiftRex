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
/// Phase 1  behavior.handle(action, preCtx)   — all Behaviors, pre-mutation state
/// Phase 2  consequence.mutation.runEndoMut(&state) — all mutations, zero-copy inout
/// Phase 3  consequence.effect.runReader(postCtx)  — all effects, post-mutation state
/// ```
///
/// Because every `Behavior.handle` call in phase 1 sees the same pre-mutation state, composing
/// two behaviors with ``combine(_:_:)`` gives them identical views of the world — neither
/// behavior's logic can depend on the other's mutations.
///
/// ## Creating a Behavior
///
/// The full closure form gives access to the bare action and a ``PreReducerContext`` with
/// pre-mutation state and call-site information:
///
/// ```swift
/// // Full form — action and pre-mutation context; environment in produce
/// let loggerBehavior = Behavior<AppAction, AppState, AppEnvironment> { action, context in
///     let before = context.stateBefore
///     return .react { ctx in
///         .just(.log(action: action, before: before, after: await ctx.liveState))
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
/// - ``liftState(_:)`` — widens via `WritableKeyPath`
/// - ``liftState(_:)`` — widens via `Lens`
/// - ``liftState(_:)`` — widens via `Prism` (optional enum state)
/// - ``liftState(_:)`` — widens via `AffineTraversal`
/// - ``liftEnvironment(_:)`` — narrows via a projection closure
/// - ``lift(action:state:environment:)`` and overloads — all three axes at once
///
/// - Note: `Behavior.handle` is `@MainActor`. The ``Store`` calls it on the main actor,
///   so `context.stateBefore` is always safe to call directly inside the closure.
public struct Behavior<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    /// The core function: given an action and a pre-mutation context, returns the complete
    /// consequence (mutation + effect) for this action.
    ///
    /// - **Phase 1**: Called with `context` reflecting the current (pre-mutation) state and
    ///   the call-site source location.
    /// - The returned ``Consequence`` is applied by the Store in phases 2 and 3.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here — move
    ///   async work into the returned `Consequence.react(_:)` closure.
    public let handle: @MainActor @Sendable (
        _ action: Action,
        _ context: PreReducerContext<State>
    ) -> Consequence<State, Environment, Action>

    /// The **state** side: given the post-mutation state, the complete set of ``Channel``s that should
    /// be alive (Elm's `Sub`) — or `nil` when this behavior tree has **no** `supervise` at all. The
    /// Store reconciles it after every change; ``combine(_:_:)`` unions it; the lifts thread it through.
    /// Build it with ``supervise(_:)``.
    package let supervisor: (@MainActor @Sendable (_ state: State) -> Keep<Action, Environment>)?

    /// Whether this behavior tree contains **any** `supervise` (the state-driven axis) — *derived*
    /// from the presence of a supervisor, never a separate flag that can drift out of sync (exactly
    /// like `isEmpty` derives from `count`). The ``Store`` reconciles state-driven channels only when
    /// this is `true`, so a feature that never supervises is a **true bypass** — phase 5 reads no state
    /// and does no work, no matter how many channels *other* features keep.
    package var supervises: Bool { supervisor != nil }

    /// The per-feature units, in composition order. ``identity`` is the empty list, ``combine(_:_:)``
    /// concatenates, and ``handle`` is a single flat pass over them — no nested closure tree.
    let units: [@MainActor @Sendable (
        _ action: Action,
        _ context: PreReducerContext<State>
    ) -> Consequence<State, Environment, Action>]

    init(
        units: [@MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Consequence<State, Environment, Action>],
        supervisor: (@MainActor @Sendable (State) -> Keep<Action, Environment>)? = nil
    ) {
        self.units = units
        self.supervisor = supervisor
        if units.isEmpty {
            self.handle = { _, _ in .doNothing }
        } else if units.count == 1 {
            self.handle = units[0]
        } else {
            self.handle = { @MainActor action, context in
                // Run each unit once (all see the same pre-mutation state), then fold flatly.
                // ReducerOutcome.combine absorbs `.unchanged`, so an all-no-op composition stays
                // `.unchanged` and the Store skips notifications. Effects merge in phase 3.
                let consequences = units.map { $0(action, context) }
                let mutation = consequences.reduce(ReducerOutcome<State>.unchanged) {
                    .combine($0, $1.mutation)
                }
                let effect = Reader<PostReducerContext<State, Environment>, Effect<Action>> { postContext in
                    consequences.reduce(Effect<Action>.empty) {
                        .combine($0, $1.effect.runReader(postContext))
                    }
                }
                return Consequence(mutation: mutation, effect: effect)
            }
        }
    }

    /// Creates a `Behavior` from a `handle` closure.
    ///
    /// - Parameter handle: The closure that maps `(Action, PreReducerContext<State>)` to
    ///   ``Consequence``. Called on `@MainActor` by the Store during phase 1.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Consequence<State, Environment, Action>
    ) {
        self.init(units: [handle])
    }

    /// Creates a `Behavior` from a single `handle` closure and an optional `supervisor` — used by the
    /// lifts to carry the state-driven axis through a transform (`nil` when the source never supervises).
    init(
        handle: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Consequence<State, Environment, Action>,
        supervisor: (@MainActor @Sendable (State) -> Keep<Action, Environment>)?
    ) {
        self.init(units: [handle], supervisor: supervisor)
    }
}

// MARK: - Named constructors

extension Behavior {
    /// Named constructor — equivalent to `Behavior(handle:)` but reads more naturally
    /// at the call site:
    ///
    /// ```swift
    /// let myBehavior = Behavior<AppAction, AppState, AppEnvironment>.handle { action, context in
    ///     // ...
    /// }
    /// ```
    ///
    /// - Parameter fn: The handle closure.
    /// - Returns: A `Behavior` wrapping `fn`.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Consequence<State, Environment, Action>
    ) -> Self { Behavior(handle: fn) }

    /// Creates a **state-driven** behavior — the `supervise` (Sub) side, with no action handling.
    ///
    /// `keep` returns the complete set of ``Channel``s that should be alive for the given state; the
    /// Store reconciles it after every change. Combine it with `reduce`/`react` behaviors:
    ///
    /// ```swift
    /// let appBehavior = Behavior.combine(featureBehavior, .supervise { state in
    ///     Keep { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
    /// })
    /// ```
    ///
    /// - Parameter keep: Maps state to the channels to keep alive (environment via the ``Keep`` reader).
    /// - Returns: A `Behavior` that handles no actions and supervises `keep`.
    public static func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Keep<Action, Environment>
    ) -> Self {
        Behavior(units: [], supervisor: keep)
    }

    /// A **mutation-only** behavior — reduces state per action, no effects. One of the three
    /// fluent concerns (`reduce` / `react` / `supervise`).
    public static func reduce(
        _ fn: @escaping @Sendable (_ action: Action, _ state: inout State) -> Void
    ) -> Self {
        Behavior(units: [{ action, _ in .reduce { (state: inout State) in fn(action, &state) } }])
    }

    /// An **effect-only** behavior — reacts to an action with an effect, no mutation. Mirrors
    /// `Middleware.react`. One of the three fluent concerns.
    public static func react(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    ) -> Self {
        Behavior(units: [{ action, context in Consequence(mutation: .unchanged, effect: fn(action, context)) }])
    }
}

// MARK: - Fluent chaining (instance == `self <> Self.static(...)`)

extension Behavior {
    /// Adds a mutation concern, combining it with `self` — `b.reduce { … }` ≡ `b <> .reduce { … }`.
    public func reduce(
        _ fn: @escaping @Sendable (Action, inout State) -> Void
    ) -> Self { .combine(self, .reduce(fn)) }

    /// Adds an effect concern, combining it with `self` — `b.react { … }` ≡ `b <> .react { … }`.
    public func react(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    ) -> Self { .combine(self, .react(fn)) }

    /// Adds a state-driven concern, combining it with `self` — `b.supervise { … }` ≡ `b <> .supervise { … }`.
    public func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Keep<Action, Environment>
    ) -> Self { .combine(self, .supervise(keep)) }
}

// MARK: - Reducer + Middleware

extension Behavior {
    /// Creates a `Behavior` by pairing a ``Reducer`` with a ``Middleware``.
    ///
    /// The reducer provides the `EndoMut` (phase 2 mutation) and the middleware provides the
    /// `Reader<PostReducerContext<State, Environment>, Effect<Action>>` (phase 3 effect). Both
    /// are composed into a ``Consequence`` without any intermediate state copies.
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
    ///     ``PreReducerContext`` during its `handle` call and post-mutation state inside
    ///     the returned `Reader` via ``PostReducerContext``.
    public init(
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, State, Environment>
    ) {
        self.init(
            units: [
                { action, context in
                    Consequence(
                        mutation: .mutation(reducer.reduce(action)),
                        effect: middleware.handle(action, context)
                    )
                }
            ],
            supervisor: middleware.supervisor
        )
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
        Behavior(units: lhs.units + rhs.units, supervisor: unionSupervise([lhs, rhs]))
    }

    /// Flattens a non-empty run of behaviors in a single pass — O(total units), no nesting.
    public static func sconcat(_ first: Behavior, _ rest: [Behavior]) -> Behavior {
        Behavior(units: rest.reduce(into: first.units) { $0 += $1.units }, supervisor: unionSupervise([first] + rest))
    }

    /// Unions the `supervise` axes of `behaviors` — the desired channel set for a state is the
    /// concatenation of each *supervising* behavior's set. Returns `nil` when **none** supervise, so a
    /// fully non-supervising composition stays a true bypass; otherwise only the supervising summands
    /// are resolved (the empty ones are skipped, not called with an empty result).
    static func unionSupervise(
        _ behaviors: [Behavior]
    ) -> (@MainActor @Sendable (State) -> Keep<Action, Environment>)? {
        let supervisors = behaviors.compactMap(\.supervisor)
        guard !supervisors.isEmpty else { return nil }
        return { @MainActor state in
            let keeps = supervisors.map { $0(state) }            // resolve each supervisor on @MainActor
            return Reader { env in keeps.flatMap { $0.runReader(env) } }
        }
    }
}

extension Behavior: Monoid {
    /// The no-op behavior — ignores every action, produces no mutations and no effects.
    ///
    /// Acts as the identity element for ``combine(_:_:)``:
    /// `combine(b, identity) == combine(identity, b) == b` for any behavior `b`.
    public static var identity: Behavior {
        Behavior(units: [])
    }

    /// Flattens any (possibly empty) array of behaviors in a single pass — O(total units).
    /// Identities contribute empty lists and vanish; the `supervise` axes are unioned.
    public static func mconcat(_ values: [Behavior]) -> Behavior {
        Behavior(units: values.flatMap(\.units), supervisor: unionSupervise(values))
    }
}
