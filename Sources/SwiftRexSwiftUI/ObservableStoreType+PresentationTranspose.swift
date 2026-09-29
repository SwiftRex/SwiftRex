// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
import SwiftRex

// The `Presentation` overload of `transpose` (see `StoreType+Transpose.swift`). A store of a three-stage
// ``Presentation`` swaps into an optional store of the unwrapped value: present through **both**
// `presented` and `dismissing(last:)` (so the child store — and its view — stay alive and steady while
// SwiftUI animates the sheet out), `nil` only once `dismissed`. This is the clean counterpart to the bare
// `Optional` transpose: the last value is a modeled stage, not a captured snapshot, so there is no
// dismissal flicker.

extension ObservableStoreType {
    /// Swap `Store<Presentation<T>>` into `Store<T>?`: a projection onto the presented value while
    /// `presented` **or** `dismissing`, `nil` while `dismissed`. Map it to build an optional presented
    /// view: `store.transpose().map { DetailFeature.view(store: $0, environment: …) }`.
    ///
    /// The caller depends only on whether a value is there (the presence edge) — the child observes its own
    /// state through the returned projection.
    @MainActor
    public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Presentation<Wrapped> {
        read(\Presentation<Wrapped>.wrapped.observationIsPresent)
            ? peek(\Presentation<Wrapped>.wrapped).map { current in
                StoreProjection(store: self, action: { $0 }, state: { $0.wrapped ?? current })
            }
            : nil
    }
}
#endif

#if canImport(SwiftUI) && canImport(Combine)
    extension ObservableStoreType {
        /// The observable counterpart of the core `Optional` ``SwiftRex/StoreType/transpose()``: swap
        /// `Store<T?>` into `Store<T>?`, where the caller depends only on the **presence** edge — a router
        /// body that unwraps an optional child redraws when the child appears or disappears, not on every
        /// change inside it (the child observes its own state through the returned projection).
        ///
        /// ```swift
        /// if let book = store.book.scoped(action: .action(AppAction.prism.book)).transpose() {
        ///     BookFeature.view(store: book, environment: world.bookEnv)
        /// }
        /// ```
        @MainActor
        public func transpose<Wrapped: Sendable>() -> StoreProjection<Action, Wrapped>? where State == Wrapped? {
            read(\Wrapped?.observationIsPresent)
                ? peek(\Wrapped?.self).map { current in
                    StoreProjection(store: self, action: { $0 }, state: { $0 ?? current })
                }
                : nil
        }
    }
#endif
