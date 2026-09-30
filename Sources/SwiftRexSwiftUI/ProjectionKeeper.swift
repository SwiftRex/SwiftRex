// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// Builds a view **and keeps its store alive** — the owner of a ``ViewStore`` for places where no
    /// ``OwnedStore`` property can be declared: inside a body, a router's `switch`, a `ForEach` row, a sheet's
    /// content, a static `view(store:environment:)` function.
    ///
    /// ```swift
    /// ProjectionKeeper { appStore.projection(action: { .detail($0) }, state: DetailScreen.makeViewState) } content: { viewStore in
    ///     DetailScreen(viewStore: viewStore)
    /// }
    /// ```
    ///
    /// It's the composition `(store) -> ViewStore >>> (ViewStore) -> View`, with ownership in the middle: `make`
    /// (usually a projection) runs the first time this position appears and again only when `id` changes; the
    /// observed store it builds lives in SwiftUI's state for this view, so re-rendering the parent never rebuilds
    /// it, re-subscribes it, or loses what its views recorded. `content` runs on every render with the same
    /// ``ViewStore``.
    ///
    /// Pass an `id` when the same position can come to show a *different* store (a sheet for another item).
    /// Handed a view store that already signals the same way (a router passing `viewStore.focus(…).transpose()`
    /// to a feature's view), it reuses it instead of building a second engine that re-follows the first.
    /// `@Feature`'s generated view is one of these.
    @MainActor
    public struct ProjectionKeeper<Action: Sendable, State: Sendable, Content: View>: View {
        @SwiftUI.State private var box = Box()
        private let id: AnyHashable?
        private let strategy: ViewStrategy
        private let make: @MainActor () -> ViewStore<Action, State>
        private let content: @MainActor (ViewStore<Action, State>) -> Content

        public init(
            id: AnyHashable? = nil,
            strategy: ViewStrategy = .automatic,
            _ make: @escaping @MainActor () -> any StoreType<Action, State>,
            @ViewBuilder content: @escaping @MainActor (ViewStore<Action, State>) -> Content
        ) {
            self.id = id
            self.strategy = strategy
            self.make = { ViewStore.owning(make(), strategy: strategy) }
            self.content = content
        }

        public var body: some View {
            content(box.viewStore(id: id, make: make))
        }

        // A plain (non-observable) box: `@State` keeps the first instance across re-inits, and reading it never
        // invalidates anything.
        @MainActor
        final class Box {
            private var current: (id: AnyHashable?, viewStore: ViewStore<Action, State>)?

            func viewStore(id: AnyHashable?, make: () -> ViewStore<Action, State>) -> ViewStore<Action, State> {
                current.flatMap { $0.id == id ? $0.viewStore : nil } ?? remember(id, make())
            }

            private func remember(_ id: AnyHashable?, _ viewStore: ViewStore<Action, State>) -> ViewStore<Action, State> {
                current = (id, viewStore)
                return viewStore
            }
        }
    }
#endif
