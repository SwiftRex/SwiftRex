// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

/// The **action-clock** branch of a ``Consequence`` — the complete outcome of *reacting to one
/// action*: an optional state mutation and an optional side effect.
///
/// `Reaction` pairs a ``ReducerOutcome`` (the mutation to apply in phase 2, or
/// ``ReducerOutcome/unchanged``) with a `Reader<PostReducerContext<State, Environment>, Effect<Action>>`
/// (the effect to schedule in phase 3). Either half can be absent — its two monoidal generators are
/// `reduce` (describe a mutation) and `produce` (describe an effect); the ``Store`` is what *mutates*
/// and *performs* them. Use the static factories to express intent clearly:
///
/// ```swift
/// Behavior<AppAction, AppState, AppEnvironment>.react { action, _ in
///     switch action {
///     case .increment:
///         // Pure mutation — no effect
///         return .reduce { $0.count += 1 }
///
///     case .fetch(let query):
///         // Pure effect — no mutation
///         return .produce { ctx in ctx.environment.api.search(query).asEffect() }
///
///     case .fetchAndShow(let query):
///         // Both: set loading flag, then fire the network request
///         return .reduce { $0.isLoading = true }
///                .produce { ctx in ctx.environment.api.search(query).asEffect() }
///
///     case .noop:
///         return .doNothing
///     }
/// }
/// ```
///
/// ## Three-phase dispatch timing
///
/// The ``Store`` processes a `Reaction` in three phases:
///
/// 1. **Phase 1** — the reaction is produced from the action and a ``PreReducerContext`` (pre-mutation
///    state). Nothing has changed yet.
/// 2. **Phase 2** — `mutation.runEndoMut(&state)` runs. All state changes happen here, on `@MainActor`.
/// 3. **Phase 3** — `produce.runReader(postCtx)` runs. ``PostReducerContext/liveState`` read here
///    returns this cycle's post-mutation state.
///
/// ## Monoid: sequential mutations, parallel effects
///
/// `Reaction` is a `Monoid` whose identity is ``doNothing``. ``combine(_:_:)`` runs `lhs.mutation`
/// then `rhs.mutation` on the same `inout State` (later mutations see earlier ones); their effects
/// are merged via ``Effect/combine(_:_:)`` and run concurrently.
public struct Reaction<State: Sendable, Environment: Sendable, Action: Sendable>: Sendable {
    package let mutation: ReducerOutcome<State>
    package let produce: Reader<PostReducerContext<State, Environment>, Effect<Action>>

    package init(
        mutation: ReducerOutcome<State>,
        produce: Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) {
        self.mutation = mutation
        self.produce = produce
    }

    /// A reaction that neither mutates state nor produces any effect.
    ///
    /// Use this as the explicit "do nothing" branch in a switch statement — it communicates
    /// intent more clearly than returning `.reduce { _ in }`:
    ///
    /// ```swift
    /// case .unknownEvent:
    ///     return .doNothing
    /// ```
    public static var doNothing: Self {
        Self(mutation: .unchanged, produce: Reader { _ in .empty })
    }

    /// A reaction that mutates state in-place without producing any effect.
    ///
    /// The closure receives the state by `inout` reference, avoiding copies of large value
    /// trees. The ``Store`` applies it in phase 2.
    ///
    /// ```swift
    /// case .setUsername(let name):
    ///     return .reduce { $0.profile.username = name }
    ///
    /// case .toggleFlag:
    ///     return .reduce { $0.flags.showBanner.toggle() }
    /// ```
    ///
    /// - Parameter f: A closure that describes the in-place mutation.
    /// - Returns: A `Reaction` with `f` as its mutation and an empty effect.
    public static func reduce(_ f: @escaping @Sendable (inout State) -> Void) -> Self {
        Self(mutation: .mutation(EndoMut(f)), produce: Reader { _ in .empty })
    }

    /// A reaction that produces a side effect without mutating state.
    ///
    /// The ``PostReducerContext`` is injected by the Store when phase 3 runs. It gives access
    /// to `ctx.environment` (synchronously) and `ctx.liveState` (on `@MainActor`). The closure must
    /// be synchronous — async work is expressed as an ``Effect`` value returned from `f`:
    ///
    /// ```swift
    /// case .load(let id):
    ///     return .produce { ctx in ctx.environment.api.fetch(id: id).asEffect() }
    ///
    /// case .trackEvent(let name):
    ///     return .produce { ctx in ctx.environment.analytics.track(name).asEffect() }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` closure that receives a ``PostReducerContext`` and returns
    ///   an ``Effect`` for the Store to perform.
    /// - Returns: A `Reaction` with identity mutation and `f` as the effect.
    public static func produce(
        _ f: @escaping @Sendable (PostReducerContext<State, Environment>) -> Effect<Action>
    ) -> Self {
        Self(mutation: .unchanged, produce: Reader(f))
    }

    /// Chains an additional effect onto an existing `Reaction`, merging it with any prior effect.
    ///
    /// This is the fluent builder for expressing "mutation AND effect" in a single expression.
    /// The new effect is combined in parallel with any existing effect via ``Effect/combine(_:_:)``:
    ///
    /// ```swift
    /// case .submit(let form):
    ///     return .reduce { $0.isLoading = true }
    ///            .produce { ctx in ctx.environment.api.submit(form).asEffect() }
    ///
    /// // Multiple effects run concurrently
    /// case .signIn(let credentials):
    ///     return .reduce { $0.isLoading = true }
    ///            .produce { ctx in ctx.environment.auth.signIn(credentials).asEffect() }
    ///            .produce { ctx in ctx.environment.analytics.track(.signInAttempt).asEffect() }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` closure that receives a ``PostReducerContext`` and returns
    ///   an ``Effect`` to combine with any existing effect.
    /// - Returns: A `Reaction` with the same mutation and a merged effect.
    public func produce(
        _ f: @escaping @Sendable (PostReducerContext<State, Environment>) -> Effect<Action>
    ) -> Self {
        Self(mutation: mutation, produce: Reader { ctx in .combine(produce.runReader(ctx), f(ctx)) })
    }
}

// MARK: - Semigroup

extension Reaction: Semigroup {
    /// Combines two reactions: mutations run sequentially (lhs then rhs), effects run in parallel.
    ///
    /// `rhs.mutation` sees any changes made by `lhs.mutation` because they share the same
    /// `inout State`. Effects from both reactions are merged via ``Effect/combine(_:_:)``.
    ///
    /// - Parameters:
    ///   - lhs: The first reaction; its mutation runs first.
    ///   - rhs: The second reaction; its mutation sees lhs's changes.
    /// - Returns: A combined reaction with sequential mutations and parallel effects.
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        Self(
            mutation: .combine(lhs.mutation, rhs.mutation),
            produce: Reader { ctx in .combine(lhs.produce.runReader(ctx), rhs.produce.runReader(ctx)) }
        )
    }
}

extension Reaction: Monoid {
    /// The identity reaction — equivalent to ``doNothing``.
    public static var identity: Self { .doNothing }
}

// MARK: - Consequence (the umbrella)

/// A single thing a ``Behavior`` does — *either* a **reaction** to an action *or* a **supervision**
/// of state. A behavior is a `Monoid` of these: `Behavior` is `[Consequence]`, with `[]` the
/// identity and `+` the composition.
///
/// The two cases are the two **clocks**:
///
/// - ``reaction(_:)`` runs on the **action clock**: given an action and pre-mutation context it
///   produces a ``Reaction`` (a `reduce` and/or `produce`), scheduled once per action.
/// - ``supervision(_:)`` runs on the **state clock**: given the post-mutation state it produces a
///   ``Supervision`` (the channels to *keep*), reconciled by diff after every change — independent of
///   whether any action reached this behavior (so it survives time-travel).
///
/// You rarely build a `Consequence` directly; the `Behavior`/`Middleware` builders
/// (`react` / `reduce` / `produce` / `supervise`) construct the right case for you.
public enum Consequence<State: Sendable, Environment: Sendable, Action: Sendable>: Sendable {
    /// An **action-clock** consequence: react to an action with a ``Reaction``.
    case reaction(@MainActor @Sendable (Action, PreReducerContext<State>) -> Reaction<State, Environment, Action>)
    /// A **state-clock** consequence: supervise the channels a state should keep alive.
    case supervision(@MainActor @Sendable (State) -> Supervision<Environment, Action>)
}
