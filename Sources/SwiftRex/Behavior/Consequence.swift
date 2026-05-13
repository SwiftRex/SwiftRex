import CoreFP
import DataStructure

/// The outcome of a `Behavior` handling one action: a state mutation and an effect, both optional.
///
/// Built via static factories so switch/case branches read as declarations of intent:
///
/// ```swift
/// Behavior { action, stateAccess in
///     switch action.action {
///     case .increment:
///         return .reduce { $0.count += 1 }
///     case .fetch(let query):
///         return .produce { env in env.api.search(query).asEffect() }
///     case .fetchAndShow(let query):
///         return .reduce { $0.isLoading = true }
///                .produce { env in env.api.search(query).asEffect() }
///     case .noop:
///         return .doNothing
///     }
/// }
/// ```
///
/// `stateAccess` captured from the outer closure reads **pre-mutation** state during phase 1
/// and **post-mutation** state inside the `produce` closure (phase 3) — same reference,
/// different moment.
public struct Consequence<State: Sendable, Environment: Sendable, Action: Sendable>: @unchecked Sendable {
    package let mutation: EndoMut<State>
    package let effect: Reader<Environment, Effect<Action>>

    package init(mutation: EndoMut<State>, effect: Reader<Environment, Effect<Action>>) {
        self.mutation = mutation
        self.effect = effect
    }

    /// No mutation, no effect.
    public static var doNothing: Self {
        Self(mutation: .identity, effect: Reader { _ in .empty })
    }

    /// State mutation only; produces no effect.
    public static func reduce(_ f: @escaping @Sendable (inout State) -> Void) -> Self {
        Self(mutation: EndoMut(f), effect: Reader { _ in .empty })
    }

    /// Effect only; leaves state unchanged.
    public static func produce(_ f: @escaping @Sendable (Environment) -> Effect<Action>) -> Self {
        Self(mutation: .identity, effect: Reader(f))
    }

    /// Chains an effect onto an existing `Consequence`, combining with any prior effect.
    /// Effects are merged in parallel — both run concurrently by the Store.
    public func produce(_ f: @escaping @Sendable (Environment) -> Effect<Action>) -> Self {
        Self(mutation: mutation, effect: Reader { env in .combine(self.effect.runReader(env), f(env)) })
    }
}

// MARK: - Semigroup

extension Consequence: Semigroup {
    /// Sequential mutations, parallel effects.
    public static func combine(_ lhs: Self, _ rhs: Self) -> Self {
        Self(
            mutation: .combine(lhs.mutation, rhs.mutation),
            effect: Reader { env in .combine(lhs.effect.runReader(env), rhs.effect.runReader(env)) }
        )
    }
}

extension Consequence: Monoid {
    public static var identity: Self { .doNothing }
}
