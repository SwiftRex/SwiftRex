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
    /// `@Feature`'s generated view is one of these.
    @MainActor
    public struct ProjectionKeeper<Action: Sendable, State: Sendable, Content: View>: View {
        @SwiftUI.State private var box = Box()
        private let id: AnyHashable?
        private let strategy: ViewStrategy
        private let make: @MainActor () -> ViewStoreEngine<Action, State>
        private let content: @MainActor (ViewStore<Action, State>) -> Content

        public init(
            id: AnyHashable? = nil,
            strategy: ViewStrategy = .automatic,
            _ make: @escaping @MainActor () -> any StoreType<Action, State>,
            @ViewBuilder content: @escaping @MainActor (ViewStore<Action, State>) -> Content
        ) {
            self.id = id
            self.strategy = strategy
            self.make = { ViewStoreEngine(make(), strategy: strategy) }
            self.content = content
        }

        public var body: some View {
            content(ViewStore(engine: box.engine(id: id, make: make)))
        }

        // A plain (non-observable) box: `@State` keeps the first instance across re-inits, and reading it never
        // invalidates anything.
        @MainActor
        final class Box {
            private var current: (id: AnyHashable?, engine: ViewStoreEngine<Action, State>)?

            func engine(id: AnyHashable?, make: () -> ViewStoreEngine<Action, State>) -> ViewStoreEngine<Action, State> {
                current.flatMap { $0.id == id ? $0.engine : nil } ?? remember(id, make())
            }

            private func remember(_ id: AnyHashable?, _ engine: ViewStoreEngine<Action, State>) -> ViewStoreEngine<Action, State> {
                current = (id, engine)
                return engine
            }
        }
    }
#endif
