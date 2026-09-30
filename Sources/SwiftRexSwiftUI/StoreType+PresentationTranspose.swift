// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    import SwiftRex

    extension StoreType {
        /// Swaps a store of a ``Presentation`` into a stream of optional stores of the presented value: a child
        /// store while `presented` **or** `dismissing(last:)`, `nil` once `dismissed` — emitted on that edge only.
        ///
        /// The same mechanics (and pitfalls) as the optional form, `StoreType.transpose()` where `State == T?`:
        /// present on `.some`, tear down on `nil`, and don't keep a child store past its `nil`.
        public func transpose<Wrapped: Sendable>() -> StateStream<StoreProjection<Action, Wrapped>?> where State == Presentation<Wrapped> {
            StoreProjection(store: self, action: { $0 }, state: { $0.wrapped }).transpose()
        }
    }
#endif
