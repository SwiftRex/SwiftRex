import CoreFP
import DataStructure

/// The complete outcome of a ``Behavior`` handling one action: an optional state mutation
/// and an optional side effect.
///
/// `Consequence` is the return value of every ``Behavior/handle`` call. It pairs an
/// `EndoMut<State>` (the mutation to apply in phase 2) with a `Reader<Environment, Effect<Action>>`
/// (the effect to schedule in phase 3). Either half can be absent — use the static factories to
/// express intent clearly:
///
/// ```swift
/// Behavior<AppAction, AppState, AppEnvironment> { action, stateAccess in
///     switch action.action {
///     case .increment:
///         // Pure mutation — no effect
///         return .reduce { $0.count += 1 }
///
///     case .fetch(let query):
///         // Pure effect — no mutation
///         return .produce { env in env.api.search(query).asEffect() }
///
///     case .fetchAndShow(let query):
///         // Both: set loading flag, then fire the network request
///         return .reduce { $0.isLoading = true }
///                .produce { env in env.api.search(query).asEffect() }
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
/// 1. **Phase 1** — ``Behavior/handle`` is called with pre-mutation `StateAccess`. The
///    `Consequence` is produced but nothing has changed yet.
/// 2. **Phase 2** — `mutation.runEndoMut(&state)` is called. All state changes happen here,
///    atomically, on `@MainActor`.
/// 3. **Phase 3** — `effect.runReader(environment)` is called. `StateAccess` now returns
///    post-mutation state, so effects that need to read the new state can do so.
///
/// ## State access timing
///
/// The `stateAccess` reference captured from the outer ``Behavior`` closure reads:
/// - **Pre-mutation** state when called during ``Behavior/handle`` (phase 1).
/// - **Post-mutation** state when called inside the `produce` closure (phase 3).
///
/// This is the same object, accessed at different moments:
///
/// ```swift
/// Behavior { action, stateAccess in
///     let before = stateAccess.snapshotState()    // phase 1 — pre-mutation
///
///     return .reduce { $0.count += 1 }
///            .produce { _ in
///                let after = stateAccess.snapshotState()  // phase 3 — post-mutation
///                return .just(.log(before: before, after: after))
///            }
/// }
/// ```
///
/// ## Semigroup: sequential mutations, parallel effects
///
/// ``combine(_:_:)`` runs `lhs.mutation` then `rhs.mutation` on the same `inout State`, so
/// later mutations see earlier ones. Their effects are merged via ``Effect/combine(_:_:)``
/// and run concurrently by the Store.
public struct Consequence<State: Sendable, Environment: Sendable, Action: Sendable>: @unchecked Sendable {
    package let mutation: EndoMut<State>
    package let effect: Reader<Environment, Effect<Action>>

    package init(mutation: EndoMut<State>, effect: Reader<Environment, Effect<Action>>) {
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
        Self(mutation: .identity, effect: Reader { _ in .empty })
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
        Self(mutation: EndoMut(f), effect: Reader { _ in .empty })
    }

    /// A consequence that produces a side effect without mutating state.
    ///
    /// The `Environment` is injected by the Store when phase 3 runs. The closure must be
    /// synchronous — async work is expressed as an ``Effect`` value returned from `f`:
    ///
    /// ```swift
    /// case .load(let id):
    ///     return .produce { env in env.api.fetch(id: id).asEffect() }
    ///
    /// case .trackEvent(let name):
    ///     return .produce { env in env.analytics.track(name).asEffect() }
    /// ```
    ///
    /// - Parameter f: A closure that receives the environment and returns an ``Effect``.
    /// - Returns: A `Consequence` with identity mutation and `f` wrapped in a `Reader`.
    public static func produce(_ f: @escaping @Sendable (Environment) -> Effect<Action>) -> Self {
        Self(mutation: .identity, effect: Reader(f))
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
    ///            .produce { env in env.api.submit(form).asEffect() }
    ///
    /// // Multiple effects run concurrently
    /// case .signIn(let credentials):
    ///     return .reduce { $0.isLoading = true }
    ///            .produce { env in env.auth.signIn(credentials).asEffect() }
    ///            .produce { env in env.analytics.track(.signInAttempt).asEffect() }
    /// ```
    ///
    /// - Parameter f: A closure that receives the environment and returns an ``Effect``
    ///   to combine with any existing effect.
    /// - Returns: A `Consequence` with the same mutation and a merged effect.
    public func produce(_ f: @escaping @Sendable (Environment) -> Effect<Action>) -> Self {
        Self(mutation: mutation, effect: Reader { env in .combine(self.effect.runReader(env), f(env)) })
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
            effect: Reader { env in .combine(lhs.effect.runReader(env), rhs.effect.runReader(env)) }
        )
    }
}

extension Consequence: Monoid {
    /// The identity consequence — equivalent to ``doNothing``.
    ///
    /// Composing with `identity` leaves any other `Consequence` unchanged.
    public static var identity: Self { .doNothing }
}
