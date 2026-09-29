// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
import SwiftRex

// `transpose` on an observed store — `Store<T?>` (or `Store<Presentation<T>>`) into `Store<T>?` — where the
// caller depends on the **presence edge only**, never on the child's contents (the child observes its own
// state through the returned projection). Three overloads:
//
//   • `Presentation<T>` — present through **both** `presented` and `dismissing(last:)`, so the child stays
//     alive and steady while SwiftUI animates the sheet out; `nil` only once `dismissed`. The last value is a
//     modeled stage, not a captured snapshot, so there is no dismissal flicker.
//   • `T?` — reach it through a key path: `store.child.scoped(action:).transpose()`.
//   • a closure lane — `store.transpose(action:state:)`, for what no key path expresses (an affine preview).
//
// The core `StoreType.transpose()` also exists, but decides presence by reading the whole `state` — on an
// observed store inside a body, use these.

extension ObservableStoreType {
    /// Swap `Store<Presentation<T>>` into `Store<T>?`: a projection onto the presented value while
    /// `presented` **or** `dismissing`, `nil` while `dismissed`. Reach the slice through a scoped store:
    ///
    /// ```swift
    /// if let editor = store.editor.scoped(action: .action(\.editor)).transpose() {
    ///     EditorFeature.view(store: editor, environment: world.editorEnv)
    /// }
    /// ```
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
        /// The observable counterpart of the core `Optional` `transpose()` on `StoreType`: swap
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

#if canImport(SwiftUI) && canImport(Combine)
    extension ObservableStoreType {
        /// Projects through a **closure** lane and swaps `Store<T?>` into `Store<T>?` — the caller depends
        /// only on the **presence** edge (`state(…) != nil`), not on the whole state.
        ///
        /// This is the form for lanes no key path can express — an affine `preview` (the top of a stack, an
        /// enum case), a `Relay.Scope`'s `state.preview` in a router:
        ///
        /// ```swift
        /// if let screen = store.transpose(action: scope.action.review, state: scope.state.preview) {
        ///     Feature.view(store: screen, environment: scope.environment.narrow(world))
        /// }
        /// ```
        ///
        /// Prefer it over `store.projection(action:state:).transpose()`, which reads the observed store's
        /// whole `state` to decide presence and so makes the caller depend on every change. With a key-path
        /// lane, `store.child.scoped(action:).transpose()` is the same thing.
        ///
        /// The presence dependency is identified by the call site plus the lane's types (see
        /// ``read(derived:id:fileID:line:column:)``); pass `id` when one call site transposes different lanes
        /// of the same types. The returned projection follows the value live, falling back to the last
        /// present value for the frame on which it disappears.
        @MainActor
        public func transpose<LocalAction: Sendable, Wrapped: Sendable>(
            action: @escaping @Sendable (LocalAction) -> Action,
            state: @escaping @Sendable (State) -> Wrapped?,
            id: AnyHashableSendable? = nil,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> StoreProjection<LocalAction, Wrapped>? {
            let present = read(
                derived: { state($0) != nil },
                types: [ObjectIdentifier(LocalAction.self), ObjectIdentifier(Wrapped.self)],
                id: id,
                site: "\(fileID):\(line):\(column)"
            )
            return present
                ? state(untrackedState).map { current in
                    StoreProjection(store: self, action: action, state: { state($0) ?? current })
                }
                : nil
        }
    }
#endif
