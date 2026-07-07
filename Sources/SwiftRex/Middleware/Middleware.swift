// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

/// The side-effecting half of a feature's logic — a simplified ``Behavior`` that **produces** effects
/// and **supervises** channels but never mutates state (that is ``Reducer``'s job). Pair the two with
/// `Behavior(reducer:middleware:)`.
///
/// `Middleware` shares `Behavior`'s model: it is a monoid of ``Consequence``s, but only the
/// effect-producing (`.reaction` with no mutation) and `.supervision` kinds. It receives every
/// dispatched action with a ``PreReducerContext`` and returns a
/// `Reader<PostReducerContext<State, Environment>, Effect<Action>>` the ``Store`` performs in phase 3.
///
/// ## Describe, don't do
///
/// `produce` describes an effect; `supervise` describes the channels to keep. The Store performs and
/// keeps them — the middleware itself runs nothing.
///
/// ## Composition & lifting
///
/// `Middleware` is a **Semigroup** and **Monoid**: ``combine(_:_:)`` concatenates consequence lists
/// (effects merge and run concurrently, supervisions union). Use ``liftAction(_:)`` /
/// ``liftState(_:)`` / ``liftEnvironment(_:)`` to embed a feature middleware in the app's types.
public struct Middleware<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {
    /// The action-clock unit a `.reaction` consequence carries.
    typealias ReactionUnit = @MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<Action, State, Environment>
    /// The state-clock unit a `.supervision` consequence carries.
    typealias SupervisionUnit = @MainActor @Sendable (State) -> Supervision<Action, Environment>

    /// The consequences — effect-producing reactions and supervisions; never a mutation.
    package let consequences: [Consequence<Action, State, Environment>]

    /// The **action** side: folds every effect-producing reaction into one deferred
    /// `Reader<PostReducerContext, Effect>` the Store runs in phase 3. Precomputed at construction.
    ///
    /// - Note: Always called on `@MainActor`. Do not perform blocking work here.
    public let handle: @MainActor @Sendable (
        _ action: Action,
        _ context: PreReducerContext<State>
    ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>

    /// The **state** side: unions every supervision into the complete ``Supervision`` for a state, or
    /// `nil` when the middleware never supervises (the phase-5 bypass). Derived, never a drifting flag.
    package let supervisor: (@MainActor @Sendable (_ state: State) -> Supervision<Action, Environment>)?

    /// Whether this middleware supervises any channels — `true` iff `supervisor != nil`.
    package var supervises: Bool { supervisor != nil }

    /// The primitive initialiser: a `Middleware` *is* its consequence list. `handle`/`supervisor`
    /// are folded once, here.
    package init(consequences: [Consequence<Action, State, Environment>]) {
        self.consequences = consequences
        let reactions: [ReactionUnit] = consequences.compactMap {
            if case let .reaction(f) = $0 { f } else { nil }
        }
        let supervisions: [SupervisionUnit] = consequences.compactMap {
            if case let .supervision(f) = $0 { f } else { nil }
        }
        if reactions.isEmpty {
            handle = { _, _ in Reader { _ in .empty } }
        } else if reactions.count == 1 {
            let only = reactions[0]
            handle = { action, context in only(action, context).produce }
        } else {
            handle = { @MainActor action, context in
                // Capture each reaction's produce reader on @MainActor (phase 1); the combined
                // Reader merges them lazily in phase 3 — no eager effect evaluation.
                let readers = reactions.map { $0(action, context).produce }
                return Reader { ctx in readers.reduce(Effect.empty) { .combine($0, $1.runReader(ctx)) } }
            }
        }
        if supervisions.isEmpty {
            supervisor = nil
        } else {
            supervisor = { @MainActor state in
                let keeps = supervisions.map { $0(state) }
                return Reader { env in keeps.flatMap { $0.runReader(env) } }
            }
        }
    }

    /// Creates a `Middleware` from a `handle` closure and an optional `supervisor`. Providing a
    /// supervisor means it supervises (the Store reconciles its channels); omitting it means it
    /// never does — so the flag can't desync from reality.
    ///
    /// - Parameters:
    ///   - handle: Maps `(Action, PreReducerContext)` to the effect `Reader` (the action side).
    ///   - supervisor: Maps state to the channels to keep alive (the state side), or `nil` for none.
    public init(
        handle: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>,
        supervisor: (@MainActor @Sendable (State) -> Supervision<Action, Environment>)? = nil
    ) {
        self.init(
            consequences: [.reaction { action, context in Reaction(mutation: .unchanged, produce: handle(action, context)) }]
                + (supervisor.map { [.supervision($0)] } ?? [])
        )
    }
}

extension Middleware {
    /// Creates an **effect-producing** middleware — the `produce` (Cmd) side. Equivalent to
    /// `Middleware(handle:)`.
    public static func produce(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self { Middleware(handle: fn) }

    /// Creates a **state-driven** middleware — the `supervise` (Sub) side, handling no actions.
    ///
    /// ```swift
    /// let socketMiddleware = Middleware<A, S, Env>.supervise { state in
    ///     Supervision { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
    /// }
    /// ```
    public static func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Supervision<Action, Environment>
    ) -> Self {
        Middleware(consequences: [.supervision(keep)])
    }

    /// Adds an effect concern, combining it with `self` — `m.produce { … }` ≡ `m <> .produce { … }`.
    public func produce(
        _ fn: @escaping @MainActor @Sendable (Action, PreReducerContext<State>) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self { .combine(self, .produce(fn)) }

    /// Adds a state-driven concern, combining it with `self` — `m.supervise { … }` ≡ `m <> .supervise { … }`.
    public func supervise(
        _ keep: @escaping @MainActor @Sendable (State) -> Supervision<Action, Environment>
    ) -> Self { .combine(self, .supervise(keep)) }
}

// MARK: - Named constructors

extension Middleware {
    /// Named constructor — equivalent to `Middleware(handle:)` but reads more naturally at the call
    /// site:
    ///
    /// ```swift
    /// let myMiddleware = Middleware<AppAction, AppState, AppEnvironment>.handle { action, context in
    ///     Reader { ctx in ... }
    /// }
    /// ```
    public static func handle(
        _ fn: @escaping @MainActor @Sendable (
            _ action: Action,
            _ context: PreReducerContext<State>
        ) -> Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) -> Self { Middleware(handle: fn) }
}

// MARK: - Semigroup & Monoid

extension Middleware: Semigroup {
    /// Combines two middlewares by concatenating their consequence lists: both see the same action
    /// and pre-mutation context; their effects merge via ``Effect/combine(_:_:)`` and run
    /// concurrently; their supervisions union.
    public static func combine(_ lhs: Middleware, _ rhs: Middleware) -> Middleware {
        Middleware(consequences: lhs.consequences + rhs.consequences)
    }
}

extension Middleware: Monoid {
    /// The no-op middleware — the empty consequence list. Ignores every action and produces no effects.
    public static var identity: Middleware {
        Middleware(consequences: [])
    }
}
