// SPDX-License-Identifier: Apache-2.0

// MARK: - transpose — swap the nesting: Store<Optional<T>> → Optional<Store<T>>
//
// A projection over an optional slice is a *store of an optional* (`StoreProjection<A, T?>`). A child
// screen, though, wants a *store of the unwrapped value* (`Store<A, T>`) — and, when the value is absent,
// no store at all. `transpose()` swaps the two type constructors' nesting: `Store<Optional<T>>` becomes
// `Optional<Store<T>>`, the store analogue of transposing `Optional<[T]>` ⇄ `[Optional<T>]`.
//
// It is NOT a lawful `sequence`/`traverse` (a `Store` is not `Traversable`); the swap works because a
// store is *peekable* — the current value decides the nesting at call time: `.some(store)` when present,
// `nil` when absent. The unwrapped store reads the live value, falling back to the value captured at
// `transpose()`-time on the transient frame where the source reads `nil` — so it never force-unwraps and
// it holds the last value steady across a dismissal (the `Presentation` overload in SwiftRexSwiftUI makes
// that retention a modeled `dismissing(last:)` stage). Re-evaluated each render: once the value is gone
// the outer `nil` tears the unwrapped store (and its view) down.

extension StoreType {
    /// Swap `Store<T?>` into `Store<T>?`: a projection onto the unwrapped value when it is present, or
    /// `nil` when absent. Map the result to build an optional child view: `store.transpose().map { … }`.
    @MainActor
    public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Wrapped? {
        state.map { current in StoreProjection(store: self, action: { $0 }, state: { $0 ?? current }) }
    }
}
