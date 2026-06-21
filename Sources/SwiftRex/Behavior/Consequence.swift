import CoreFP
import DataStructure

/// The complete outcome of a ``Behavior`` handling one action: an optional state mutation
/// and an optional side effect.
///
/// `Consequence` is the return value of every ``Behavior/handle`` call. It pairs a
/// ``ReducerOutcome`` (the state mutation to apply in phase 2, or ``ReducerOutcome/unchanged``)
/// with a `Reader<PostReducerContext<State, Environment>, Effect<Action>>`
/// (the effect to schedule in phase 3). Either half can be absent — use the static factories
/// to express intent clearly:
///
/// ```swift
/// Behavior<AppAction, AppState, AppEnvironment> { action, _ in
///     switch action {
///     case .increment:
///         // Pure mutation — no effect
///         return .reduce { $0.count += 1 }
///
///     case .fetch(let query):
///         // Pure effect — no mutation
///         return .react { ctx in ctx.environment.api.search(query).asEffect() }
///
///     case .fetchAndShow(let query):
///         // Both: set loading flag, then fire the network request
///         return .reduce { $0.isLoading = true }
///                .react { ctx in ctx.environment.api.search(query).asEffect() }
///
///     case .noop:
///         return .doNothing
///     }
/// }
/// ```
///
/// ## Three-phase dispatch timing
///
/// The ``Store`` processes a `Consequence` in three phases:
///
/// 1. **Phase 1** — ``Behavior/handle`` is called with a ``PreReducerContext`` giving access
///    to pre-mutation state. The `Consequence` is produced but nothing has changed yet.
/// 2. **Phase 2** — `mutation.runEndoMut(&state)` is called. All state changes happen here,
///    atomically, on `@MainActor`.
/// 3. **Phase 3** — `effect.runReader(postCtx)` is called. ``PostReducerContext/liveState``
///    read here returns this cycle's post-mutation state — via `await MainActor.run { ctx.liveState }`
///    or the Combine / RxSwift / ReactiveSwift `readLiveState()` helpers. (Read later, from an
///    async effect, it reflects the Store's state at that moment instead.)
///
/// ## Semigroup: sequential mutations, parallel effects
///
/// ``combine(_:_:)`` runs `lhs.mutation` then `rhs.mutation` on the same `inout State`, so
/// later mutations see earlier ones. Their effects are merged via ``Effect/combine(_:_:)``
/// and run concurrently by the Store.
public struct Consequence<State: Sendable, Environment: Sendable, Action: Sendable>: Sendable {
    package let mutation: ReducerOutcome<State>
    package let effect: Reader<PostReducerContext<State, Environment>, Effect<Action>>

    package init(
        mutation: ReducerOutcome<State>,
        effect: Reader<PostReducerContext<State, Environment>, Effect<Action>>
    ) {
        self.mutation = mutation
        self.effect = effect
    }

    /// A consequence that neither mutates state nor produces any effect.
    ///
    /// Use this as the explicit "do nothing" branch in a switch statement — it communicates
    /// intent more clearly than returning `.reduce { _ in }`:
    ///
    /// ```swift
    /// case .unknownEvent:
    ///     return .doNothing
    /// ```
    public static var doNothing: Self {
        Self(mutation: .unchanged, effect: Reader { _ in .empty })
    }

    /// A consequence that mutates state in-place without producing any effect.
    ///
    /// The closure receives the state by `inout` reference, avoiding copies of large value
    /// trees. Prefer this over the Endo or returning a new state when the mutation is
    /// expressed naturally as in-place changes:
    ///
    /// ```swift
    /// case .setUsername(let name):
    ///     return .reduce { $0.profile.username = name }
    ///
    /// case .toggleFlag:
    ///     return .reduce { $0.flags.showBanner.toggle() }
    /// ```
    ///
    /// - Parameter f: A closure that mutates the state in place.
    /// - Returns: A `Consequence` with `f` as its mutation and an empty effect.
    public static func reduce(_ f: @escaping @Sendable (inout State) -> Void) -> Self {
        Self(mutation: .mutation(EndoMut(f)), effect: Reader { _ in .empty })
    }

    /// A consequence that produces a side effect without mutating state.
    ///
    /// The ``PostReducerContext`` is injected by the Store when phase 3 runs. It gives access
    /// to `ctx.environment` (synchronously, from any context) and `ctx.liveState` (on
    /// `@MainActor`). The closure must be synchronous — async work is expressed as an ``Effect``
    /// value returned from `f`:
    ///
    /// ```swift
    /// case .load(let id):
    ///     return .react { ctx in ctx.environment.api.fetch(id: id).asEffect() }
    ///
    /// case .trackEvent(let name):
    ///     return .react { ctx in ctx.environment.analytics.track(name).asEffect() }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` closure that receives a ``PostReducerContext`` and returns
    ///   an ``Effect``.
    /// - Returns: A `Consequence` with identity mutation and `f` as the effect.
    public static func react(
        _ f: @escaping @Sendable (PostReducerContext<State, Environment>) -> Effect<Action>
    ) -> Self {
        Self(mutation: .unchanged, effect: Reader(f))
    }

    /// Chains an additional effect onto an existing `Consequence`, merging it with any
    /// prior effect.
    ///
    /// This is the fluent builder for expressing "mutation AND effect" in a single expression.
    /// The new effect is combined in parallel with any existing effect via
    /// ``Effect/combine(_:_:)`` — both run concurrently:
    ///
    /// ```swift
    /// case .submit(let form):
    ///     return .reduce { $0.isLoading = true }
    ///            .react { ctx in ctx.environment.api.submit(form).asEffect() }
    ///
    /// // Multiple effects run concurrently
    /// case .signIn(let credentials):
    ///     return .reduce { $0.isLoading = true }
    ///            .react { ctx in ctx.environment.auth.signIn(credentials).asEffect() }
    ///            .react { ctx in ctx.environment.analytics.track(.signInAttempt).asEffect() }
    /// ```
    ///
    /// - Parameter f: A `@Sendable` closure that receives a ``PostReducerContext`` and returns
    ///   an ``Effect`` to combine with any existing effect.
    /// - Returns: A `Consequence` with the same mutation and a merged effect.
    public func react(
        _ f: @escaping @Sendable (PostReducerContext<State, Environment>) -> Effect<Action>
    ) -> Self {
        Self(mutation: mutation, effect: Reader { ctx in .combine(self.effect.runReader(ctx), f(ctx)) })
    }
}

// MARK: - Semigroup

extension Consequence: Semigroup {
    /// Combines two consequences: mutations run sequentially (lhs then rhs), effects run in parallel.
    ///
    /// `rhs.mutation` sees any changes made by `lhs.mutation` because they share the same
    /// `inout State`. Effects from both consequences are merged via ``Effect/combine(_:_:)``
    /// and scheduled concurrently.
    ///
    /// This is the composition used by ``Behavior/combine(_:_:)`` when two behaviors handle
    /// the same action.
    ///
    /// - Parameters:
    ///   - lhs: The first consequence; its mutation runs first.
    ///   - rhs: The second consequence; its mutation sees lhs's changes.
    /// - Returns: A combined consequence with sequential mutations and parallel effects.
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        Self(
            mutation: .combine(lhs.mutation, rhs.mutation),
            effect: Reader { ctx in .combine(lhs.effect.runReader(ctx), rhs.effect.runReader(ctx)) }
        )
    }
}

extension Consequence: Monoid {
    /// The identity consequence — equivalent to ``doNothing``.
    ///
    /// Composing with `identity` leaves any other `Consequence` unchanged.
    public static var identity: Self { .doNothing }
}
