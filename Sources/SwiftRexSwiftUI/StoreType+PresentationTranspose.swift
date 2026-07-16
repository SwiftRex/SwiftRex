// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex

// The `Presentation` overload of `transpose` (see `StoreType+Transpose.swift`). A store of a three-stage
// ``Presentation`` swaps into an optional store of the unwrapped value: present through **both**
// `presented` and `dismissing(last:)` (so the child store — and its view — stay alive and steady while
// SwiftUI animates the sheet out), `nil` only once `dismissed`. This is the clean counterpart to the bare
// `Optional` transpose: the last value is a modeled stage, not a captured snapshot, so there is no
// dismissal flicker.

extension StoreType {
    /// Swap `Store<Presentation<T>>` into `Store<T>?`: a projection onto the presented value while
    /// `presented` **or** `dismissing`, `nil` while `dismissed`. Map it to build an optional presented
    /// view: `store.transpose().map { DetailFeature.view(store: $0, environment: …) }`.
    @MainActor
    public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Presentation<Wrapped> {
        state.wrapped.map { current in
            StoreProjection(store: self, action: { $0 }, state: { $0.wrapped ?? current })
        }
    }
}
#endif
