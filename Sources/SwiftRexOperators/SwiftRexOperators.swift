import SwiftRex
import CoreFPOperators
import DataStructureOperators

// MARK: - Semigroup / Monoid
//
// `<>` is already generic over `Semigroup` in CoreFPOperators:
//
//     public func <> <S: Semigroup>(_ lhs: S, _ rhs: S) -> S { .combine(lhs, rhs) }
//
// Since Effect, Reducer, and (future) Middleware and ActionHandler all conform to Semigroup,
// the `<>` operator works for them automatically — no SwiftRex-specific overload is needed.
//
//     effectA <> effectB           // Effect.combine
//     reducerA <> reducerB         // Reducer.combine

// MARK: - Effect Functor

/// `f <£> effect` — functor map, transform on the left.
public func <£> <A: Sendable, B: Sendable>(
    _ f: @Sendable @escaping (A) -> B,
    _ effect: Effect<A>
) -> Effect<B> {
    effect.map(f)
}

/// `effect <&> f` — functor map, container on the left.
public func <&> <A: Sendable, B: Sendable>(
    _ effect: Effect<A>,
    _ f: @Sendable @escaping (A) -> B
) -> Effect<B> {
    effect.map(f)
}

// MARK: - Effect Applicative

/// `effectF <*> effectA` — applicative apply.
///
/// Runs both effects concurrently; when both have emitted their first value, applies
/// the function from `effectF` to the value from `effectA` and dispatches the result.
///
/// Combine with `<£>` for the standard applicative style:
/// ```swift
/// curry { profile, settings in AppState(profile: profile, settings: settings) }
///     <£> fetchProfile
///     <*> fetchSettings
/// ```
public func <*> <A: Sendable, B: Sendable>(
    _ effectF: Effect<@Sendable (A) -> B>,
    _ effectA: Effect<A>
) -> Effect<B> {
    effectF.zipWith(effectA) { f, a in f(a) }
}

// MARK: - DispatchedAction Functor

/// `f <£> dispatched` — functor map, transform on the left.
public func <£> <A: Sendable, B: Sendable>(
    _ f: @Sendable (A) -> B,
    _ dispatched: DispatchedAction<A>
) -> DispatchedAction<B> {
    dispatched.map(f)
}

/// `dispatched <&> f` — functor map, container on the left.
public func <&> <A: Sendable, B: Sendable>(
    _ dispatched: DispatchedAction<A>,
    _ f: @Sendable (A) -> B
) -> DispatchedAction<B> {
    dispatched.map(f)
}
