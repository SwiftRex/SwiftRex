// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

/// The primary composition unit: a pure description of how a feature responds to actions **and** to
/// state changes.
///
/// A `Behavior` is a **monoid of ``Consequence``s** — literally `[Consequence]`, with the empty list
/// the identity and concatenation the composition. Each consequence is either a **reaction** to an
/// action (a ``Reaction`` — `reduce` and/or `produce`) or a **supervision** of state (a
/// ``Supervision`` — the channels to `keep`). `Behavior` unifies the jobs of ``Reducer`` (state
/// mutation), ``Middleware`` (action-driven effects), and state-driven channels in one value.
///
/// ## Describe, don't do — the purity boundary
///
/// A `Behavior` only *describes*: `reduce` describes a mutation, `produce` describes an effect,
/// `supervise` describes the channels to keep. The ``Store`` is the boundary that *does*: it
/// **mutates**, **performs**, and **keeps**. Nothing in a behavior runs an effect.
///
/// ## Two clocks
///
/// When the ``Store`` receives an action it processes the `.reaction` consequences (the **action
/// clock**) in three globally-ordered phases; after every state change it reconciles the
/// `.supervision` consequences (the **state clock**):
///
/// ```
/// Phase 1  handle(action, preCtx)         — fold all reactions, pre-mutation state
/// Phase 2  reaction.mutation.runEndoMut(&state) — all mutations, zero-copy inout
/// Phase 3  reaction.produce.runReader(postCtx)  — all effects, post-mutation state
/// Phase 5  reconcile(supervisor(state))    — state-driven channels, diffed
/// ```
///
/// Because every reaction in phase 1 sees the same pre-mutation state, composing two behaviors with
/// ``combine(_:_:)`` gives them identical views — neither can depend on the other's mutations.
///
/// ## Creating a Behavior
///
/// ```swift
/// // Grouped action builder — react, with reduce and/or produce inside
/// let loader = Behavior<AppAction, AppState, AppEnvironment>.react { action, _ in
///     guard case .load(let id) = action else { return .doNothing }
///     return .reduce  { $0.isLoading = true }
///            .produce { ctx in ctx.environment.api.fetch(id).asEffect() }
/// }
///
/// // Fluent — each concern combined into one behavior
/// let feature = Behavior<AppAction, AppState, AppEnvironment>
///     .reduce    { action, state in /* … */ }
///     .produce   { action, ctx   in Reader { c in /* … */ } }
///     .supervise { state         in Supervision { env in /* … */ } }
///
/// // From a Reducer, or a Reducer + Middleware
/// let counter = counterReducer.asBehavior()
/// let auth = Behavior(reducer: authReducer, middleware: authMiddleware)
/// ```
///
/// ## Composition & lifting
///
/// `Behavior` is a **Semigroup** and **Monoid**: ``combine(_:_:)`` concatenates the consequence
/// lists, so both behaviors' reactions run in phase 1 (same pre-mutation state), their mutations
/// sequence (lhs then rhs), their effects run concurrently, and their supervisions union. Use the
/// lift family (``liftAction(_:)``, ``liftState(_:)``, ``liftEnvironment(_:)``, ``lift(action:state:environment:)``)
/// to embed feature behaviors in the app's global types.
///
/// - Note: `handle` is `@MainActor`. The ``Store`` calls it on the main actor, so
///   `context.stateBefore` is safe to call directly inside the closure.
public struct Behavior<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    /// The action-clock unit a `.reaction` consequence carries.
    typealias ReactionUnit = @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    /// The state-clock unit a `.supervision` consequence carries.
    typealias SupervisionUnit = @MainActor @Sendable (State) -> Supervision<Action, Environment>

    /// The per-feature consequences, in composition order — the free monoid. ``identity`` is the
    /// empty list and ``combine(_:_:)`` concatenates; `handle`/`supervisor` are folded views over it.
    package let consequences: [Consequence<Action, State, Environment>]

    /// The **action** side: folds every `.reaction` consequence into one ``Reaction`` (all see the
    /// same pre-mutation `context`). Precomputed at construction so the Store hot path never rescans.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here — move async work
    ///   into the returned `Reaction`'s `produce`.
    public let handle: @MainActor @Sendable (
        _ action: Action,
        _ context: PreReducerContext<State>
    ) -> Reaction<Action, State, Environment>

    /// The **state** side: unions every `.supervision` consequence into the complete ``Supervision``
    /// for a state (Elm's `Sub`) — or `nil` when this behavior has **no** supervision at all. The
    /// Store reconciles it after every change. *Derived* from the presence of supervisions, never a
    /// flag that can drift.
    package let supervisor: (@MainActor @Sendable (_ state: State) -> Supervision<Action, Environment>)?

    /// Whether this behavior has **any** `.supervision` — `true` iff `supervisor != nil`. The
    /// ``Store`` reconciles state-driven channels only when this holds, so a behavior that never
    /// supervises is a true phase-5 bypass.
    package var supervises: Bool { supervisor != nil }

    /// The primitive initialiser: a `Behavior` *is* its consequence list. `handle` and `supervisor`
    /// are folded once, here, from the list.
    package init(consequences: [Consequence<Action, State, Environment>]) {
        self.consequences = consequences
        let reactions: [ReactionUnit] = consequences.compactMap {
            if case let .reaction(f) = $0 { f } else { nil }
        }
        let supervisions: [SupervisionUnit] = consequences.compactMap {
            if case let .supervision(f) = $0 { f } else { nil }
        }
        if reactions.isEmpty {
            handle = { _, _ in .doNothing }
        } else if reactions.count == 1 {
            handle = reactions[0]
        } else {
            handle = { @MainActor action, context in
                // Each reaction sees the same pre-mutation `context`; fold left so mutations
                // sequence lhs→rhs and effects merge. `.combine` absorbs `.unchanged`, so an
                // all-no-op fold stays `.unchanged` and the Store skips notifications.
                reactions.reduce(Reaction.doNothing) { .combine($0, $1(action, context)) }
            }
        }
        if supervisions.isEmpty {
            supervisor = nil
        } else {
            supervisor = { @MainActor state in
                let keeps = supervisions.map { $0(state) } // resolve each on @MainActor
                return Reader { env in keeps.flatMap { $0.runReader(env) } }
            }
        }
    }

    /// Creates a `Behavior` from a single grouped action handler — `(Action, PreReducerContext)` to
    /// a ``Reaction``. Equivalent to ``react(_:)``.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reaction<Action, State, Environment>
    ) {
        self.init(consequences: [.reaction(handle)])
    }

    /// Creates a `Behavior` from a single grouped action handler and an optional supervisor — used by
    /// the lifts to carry the state-driven axis through a transform (`nil` when nothing supervises).
    init(
        handle: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>,
        supervisor: (@MainActor @Sendable (State) -> Supervision<Action, Environment>)?
    ) {
        self.init(consequences: [.reaction(handle)] + (supervisor.map { [.supervision($0)] } ?? []))
    }
}

// MARK: - Named constructors

extension Behavior {
    /// The **grouped action builder** — react to an action with a ``Reaction`` (a `reduce` and/or
    /// `produce`). Pre-work shared by both halves lives in the closure body:
    ///
    /// ```swift
    /// Behavior.react { action, context in
    ///     guard case .load(let id) = action else { return .doNothing }
    ///     return .reduce  { $0.isLoading = true }
    ///            .produce { ctx in ctx.environment.api.fetch(id).asEffect() }
    /// }
    /// ```
    public static func react(
        _ fn: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reaction<Action, State, Environment>
    ) -> Self { Behavior(consequences: [.reaction(fn)]) }

    /// Alias for ``react(_:)`` — `Behavior(handle:)` spelled as a named constructor.
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reaction<Action, State, Environment>
    ) -> Self { Behavior(consequences: [.reaction(fn)]) }

    /// A **mutation-only** behavior — reduces state per action, no effects.
    public static func reduce(
        _ fn: @escaping @Sendable (_ action: Action, _ state: inout State) -> Void
    ) -> Self {
        Behavior(consequences: [.reaction { action, _ in .reduce { (state: inout State) in fn(action, &state) } }])
    }

    /// An **effect-only** behavior — produces an effect in reaction to an action, no mutation. The
    /// closure returns the `Reader<PostReducerContext, Effect>` the Store performs in phase 3.
    public static func produce(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self {
        Behavior(consequences: [.reaction { action, context in Reaction(mutation: .unchanged, produce: fn(action, context)) }])
    }

    /// A **state-driven** behavior — the `supervise` (Sub) side, with no action handling.
    ///
    /// `keep` returns the complete ``Supervision`` (the channels to keep alive) for the given state;
    /// the Store reconciles it after every change. Combine it with `reduce`/`produce` behaviors:
    ///
    /// ```swift
    /// let appBehavior = Behavior.combine(featureBehavior, .supervise { state in
    ///     Supervision { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
    /// })
    /// ```
    public static func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Supervision<Action, Environment>
    ) -> Self {
        Behavior(consequences: [.supervision(keep)])
    }
}

// MARK: - Fluent chaining (instance == `self <> Self.static(...)`)

extension Behavior {
    /// Adds a grouped action concern, combining it with `self` — `b.react { … }` ≡ `b <> .react { … }`.
    public func react(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    ) -> Self { .combine(self, .react(fn)) }

    /// Adds a mutation concern, combining it with `self` — `b.reduce { … }` ≡ `b <> .reduce { … }`.
    public func reduce(
        _ fn: @escaping @Sendable (Action, inout State) -> Void
    ) -> Self { .combine(self, .reduce(fn)) }

    /// Adds an effect concern, combining it with `self` — `b.produce { … }` ≡ `b <> .produce { … }`.
    public func produce(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self { .combine(self, .produce(fn)) }

    /// Adds a state-driven concern, combining it with `self` — `b.supervise { … }` ≡ `b <> .supervise { … }`.
    public func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Supervision<Action, Environment>
    ) -> Self { .combine(self, .supervise(keep)) }
}

// MARK: - Reducer + Middleware

extension Behavior {
    /// Creates a `Behavior` by pairing a ``Reducer`` with a ``Middleware``.
    ///
    /// The reducer provides the phase-2 mutation and the middleware provides the phase-3 effect (and
    /// any supervision). Both are composed into the consequence list without intermediate state copies.
    ///
    /// ```swift
    /// let authBehavior = Behavior(reducer: authReducer, middleware: authMiddleware)
    /// ```
    public init(
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, State, Environment>
    ) {
        self.init(
            consequences: [
                .reaction { action, _ in
                    Reaction(mutation: .mutation(reducer.reduce(action)), produce: Reader { _ in .empty })
                }
            ] + middleware.consequences
        )
    }
}

// MARK: - Semigroup & Monoid

extension Behavior: Semigroup {
    /// Combines two behaviors by concatenating their consequence lists: both reaction sets run in
    /// phase 1 with the same pre-mutation state; their mutations compose sequentially (lhs then rhs);
    /// their effects run in parallel; their supervisions union.
    ///
    /// - Important: Both behaviors' reactions see identical pre-mutation state. Sequential ordering
    ///   applies only to the `EndoMut` values in phase 2, not to what each reaction observes.
    public static func combine(_ lhs: Behavior, _ rhs: Behavior) -> Behavior {
        Behavior(consequences: lhs.consequences + rhs.consequences)
    }

    /// Flattens a non-empty run of behaviors in a single pass — O(total consequences), no nesting.
    public static func sconcat(_ first: Behavior, _ rest: [Behavior]) -> Behavior {
        Behavior(consequences: rest.reduce(into: first.consequences) { $0 += $1.consequences })
    }
}

extension Behavior: Monoid {
    /// The no-op behavior — the empty consequence list. The identity element for ``combine(_:_:)``.
    public static var identity: Behavior {
        Behavior(consequences: [])
    }

    /// Flattens any (possibly empty) array of behaviors in a single pass — O(total consequences).
    /// Identities contribute empty lists and vanish.
    public static func mconcat(_ values: [Behavior]) -> Behavior {
        Behavior(consequences: values.flatMap(\.consequences))
    }
}
