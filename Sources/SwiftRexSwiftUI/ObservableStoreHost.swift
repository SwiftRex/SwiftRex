// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// Builds an ``ObservableStore`` **once per view identity** and hands it to `content` — so re-rendering
    /// a parent doesn't rebuild the child's store, re-subscribe it, or feed the child a new reference that
    /// forces its body to run. `@Feature`'s generated `view(store:environment:)` wraps its content in one.
    ///
    /// ```swift
    /// ObservableStoreHost { appStore.projection(action: …, state: …).observable() } content: { store in
    ///     SettingsView(viewStore: store)
    /// }
    /// ```
    ///
    /// `make` runs on first appearance and again only when `id` changes — pass an `id` when the same view
    /// position can come to show a *different* store (e.g. a detail whose projection is keyed by an id the
    /// parent can swap). Without one, the first store is kept for the view's lifetime.
    @MainActor
    public struct ObservableStoreHost<Action: Sendable, State: Sendable, Content: View>: View {
        @SwiftUI.State private var box = Box()
        private let id: AnyHashable?
        private let make: @MainActor () -> ObservableStore<Action, State>
        private let content: @MainActor (ObservableStore<Action, State>) -> Content

        public init(
            id: AnyHashable? = nil,
            _ make: @escaping @MainActor () -> ObservableStore<Action, State>,
            @ViewBuilder content: @escaping @MainActor (ObservableStore<Action, State>) -> Content
        ) {
            self.id = id
            self.make = make
            self.content = content
        }

        public var body: some View {
            content(box.store(id: id, make: make))
        }

        // A plain (non-observable) box: `@State` keeps the first instance across re-inits, and reading it never
        // invalidates anything.
        @MainActor
        final class Box {
            private var current: (id: AnyHashable?, store: ObservableStore<Action, State>)?

            func store(id: AnyHashable?, make: () -> ObservableStore<Action, State>) -> ObservableStore<Action, State> {
                current.flatMap { $0.id == id ? $0.store : nil } ?? remember(id, make())
            }

            private func remember(_ id: AnyHashable?, _ store: ObservableStore<Action, State>) -> ObservableStore<Action, State> {
                current = (id, store)
                return store
            }
        }
    }
#endif
