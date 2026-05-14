import CoreFPOperators
import DataStructureOperators
import SwiftRex

// MARK: - Semigroup / Monoid
//
// `<>` is provided generically by `CoreFPOperators`:
//
//     public func <> <S: Semigroup>(_ lhs: S, _ rhs: S) -> S { .combine(lhs, rhs) }
//
// Because `Effect`, `Reducer`, and other SwiftRex types conform to `Semigroup`, the `<>`
// operator works for them automatically — no SwiftRex-specific overload is needed.
//
// Examples:
//     effectA <> effectB           // Effect.combine(effectA, effectB)  — concurrent
//     reducerA <> reducerB         // Reducer.combine(reducerA, reducerB) — sequential

// MARK: - Effect Functor

/// Functor map for ``Effect`` — transform on the left.
///
/// `<£>` is the infix alias for ``Effect/map(_:)`` used in point-free / tacit programming
/// style. Both `<£>` and `<&>` call the same underlying function; choose whichever reads
/// more naturally in context.
///
/// ```swift
/// // Lift a child action into a parent action type
/// let parentEffect: Effect<AppAction> = AppAction.child <£> childEffect
///
/// // Equivalent to:
/// let parentEffect = childEffect.map(AppAction.child)
/// ```
///
/// - Parameters:
///   - f: A `@Sendable` mapping function from `A` to `B`.
///   - effect: The ``Effect`` whose actions are to be transformed.
/// - Returns: An ``Effect<B>`` with every action mapped through `f`.
public func <£> <A: Sendable, B: Sendable>(
    _ f: @Sendable @escaping (A) -> B,
    _ effect: Effect<A>
) -> Effect<B> {
    effect.map(f)
}

/// Functor map for ``Effect`` — container on the left.
///
/// `<&>` is the infix alias for ``Effect/map(_:)`` with operand order flipped. Use it
/// when a pipeline reads more naturally with the container on the left:
///
/// ```swift
/// // Equivalent to the <£> example above, operands swapped
/// let parentEffect: Effect<AppAction> = childEffect <&> AppAction.child
/// ```
///
/// - Parameters:
///   - effect: The ``Effect`` whose actions are to be transformed.
///   - f: A `@Sendable` mapping function from `A` to `B`.
/// - Returns: An ``Effect<B>`` with every action mapped through `f`.
public func <&> <A: Sendable, B: Sendable>(
    _ effect: Effect<A>,
    _ f: @Sendable @escaping (A) -> B
) -> Effect<B> {
    effect.map(f)
}

// MARK: - DispatchedAction Functor

/// Functor map for ``DispatchedAction`` — transform on the left.
///
/// `<£>` is the infix alias for ``DispatchedAction/map(_:)``. It transforms the wrapped
/// action while preserving the original ``ActionSource`` dispatcher.
///
/// ```swift
/// // Project a global action into a child action, keeping dispatcher provenance
/// let childDispatched: DispatchedAction<ChildAction> = ChildAction.from <£> globalDispatched
/// ```
///
/// - Parameters:
///   - f: A `@Sendable` mapping function from `A` to `B`.
///   - dispatched: The ``DispatchedAction`` to transform.
/// - Returns: A ``DispatchedAction<B>`` with the same ``ActionSource`` but a transformed action.
public func <£> <A: Sendable, B: Sendable>(
    _ f: @Sendable (A) -> B,
    _ dispatched: DispatchedAction<A>
) -> DispatchedAction<B> {
    dispatched.map(f)
}

/// Functor map for ``DispatchedAction`` — container on the left.
///
/// `<&>` is the infix alias for ``DispatchedAction/map(_:)`` with operand order flipped.
/// The original ``ActionSource`` dispatcher is preserved.
///
/// ```swift
/// let childDispatched: DispatchedAction<ChildAction> = globalDispatched <&> ChildAction.from
/// ```
///
/// - Parameters:
///   - dispatched: The ``DispatchedAction`` to transform.
///   - f: A `@Sendable` mapping function from `A` to `B`.
/// - Returns: A ``DispatchedAction<B>`` with the same ``ActionSource`` but a transformed action.
public func <&> <A: Sendable, B: Sendable>(
    _ dispatched: DispatchedAction<A>,
    _ f: @Sendable (A) -> B
) -> DispatchedAction<B> {
    dispatched.map(f)
}
