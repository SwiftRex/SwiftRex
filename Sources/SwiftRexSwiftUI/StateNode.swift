// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// A position inside an observable store's state — what `store.player` returns when `Player` isn't an
    /// ``ObservableLeaf``. It records nothing by itself: reading a leaf through it (`node.title`) records
    /// that full path (`\.player.title`), and ``value`` records the node's own path.
    ///
    /// Pass nodes — not values — to subviews. The child then depends only on what **it** reads, so a
    /// fast-changing field (a playhead position) redraws the one view that shows it and nothing else:
    ///
    /// ```swift
    /// struct PlayerScreen: View {
    ///     let store: ViewStore<PlayerAction, PlayerState>
    ///     var body: some View {
    ///         Console(mixer: store.mixer)       // redraws on mixer changes only
    ///         Playhead(transport: store.transport)
    ///     }
    /// }
    /// struct Playhead: View {
    ///     let transport: StateNode<ViewStore<PlayerAction, PlayerState>, Transport>
    ///     var body: some View { Text(transport.position, format: .number) }
    /// }
    /// ```
    ///
    /// A `DynamicProperty`: stored in a view it also subscribes that view to the store's Combine signal, so
    /// nodes work under ``ViewStrategy/combine`` too (under ``ViewStrategy/observation`` that signal never fires).
    @MainActor @dynamicMemberLookup
    public struct StateNode<Source: ObservableStoreType, Value>: DynamicProperty {
        /// The observable store this node reads from.
        public let source: Source
        /// The node's position in `source`'s state.
        public let path: KeyPath<Source.State, Value>

        @ObservedObject private var observed: ObservableStore<Source.RootAction, Source.RootState>

        init(source: Source, path: KeyPath<Source.State, Value>) {
            self.source = source
            self.path = path
            _observed = ObservedObject(wrappedValue: source.root)
        }

        /// The whole value at this node — the reader depends on any change to it (by `==` when `Equatable`).
        public var value: Value { source.read(path) }

        /// A leaf member, read whole.
        public subscript<T: ObservableLeaf>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
            source.read(source.root.paths.append(path, keyPath))
        }

        /// A non-leaf member — a deeper node.
        public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> StateNode<Source, T> {
            StateNode<Source, T>(source: source, path: source.root.paths.append(path, keyPath))
        }

        /// One node per element of an `Identifiable` collection under this node — see
        /// ``ObservableStoreType/each(_:)``.
        public func each<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<Value, C>
        ) -> [StateNode<Source, C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
            source.each(source.root.paths.append(path, keyPath))
        }

        /// A store over this node's state, dispatching through `action` — an observable projection that
        /// shares the root's snapshot and registry (no new subscription). Hand it to a subview that needs
        /// to send actions or build bindings:
        ///
        /// ```swift
        /// PlayerControls(store: store.player.scoped(action: .action(\.player)))
        /// ```
        public func scoped<A: Relay.ActionAxis.EmbedsProtocol>(
            action: Relay.Scope<Source.Action, A, Source.State, Relay.Absurd<Source.State>, Never, Relay.Absurd<Never>>
        ) -> ScopedStore<Source.RootAction, Source.RootState, A.Local, Value>
        where A.Global == Source.Action, Value: Sendable {
            let embed = source.embed
            let review = action.action.review
            return ScopedStore(
                root: source.root,
                prefix: source.root.paths.append(source.prefix, path),
                embed: { embed(review($0)) }
            )
        }
    }

    extension StateNode: @MainActor Identifiable where Value: Identifiable {
        /// The element's id, read without recording a dependency (rows are keyed by id already).
        public var id: Value.ID { source.peek(path).id }
    }

    extension StateNode {
        /// `true` while the optional is `.some` — the reader depends on the presence edge only.
        public func isPresent<Wrapped>() -> Bool where Value == Wrapped? {
            source.read(source.root.paths.append(path, \Wrapped?.observationIsPresent))
        }

        /// The node of the wrapped value while `.some`, `nil` otherwise. The check depends on the presence
        /// edge only; reads through the returned node depend on what they read.
        public func unwrapped<Wrapped: Sendable>() -> StateNode<Source, Wrapped>? where Value == Wrapped? {
            source.peek(path).flatMap { current in
                isPresent()
                    ? StateNode<Source, Wrapped>(
                        source: source,
                        path: source.root.paths.append(path, \Wrapped?.[observationUnwrapped: ObservationFallback(current)])
                    )
                    : nil
            }
        }
    }

    /// A key-path argument carrying a fallback value that doesn't take part in equality — so the path stays
    /// the same dependency whatever the fallback. Observation plumbing behind ``StateNode/unwrapped()``.
    public struct ObservationFallback<Value: Sendable>: Hashable, Sendable {
        let value: Value

        init(_ value: Value) { self.value = value }

        public static func == (lhs: Self, rhs: Self) -> Bool { true }
        public func hash(into hasher: inout Hasher) {}
    }

    extension Optional where Wrapped: Sendable {
        /// The wrapped value, or the fallback once `nil` (a node can outlive its value for a frame).
        /// Observation plumbing behind ``StateNode/unwrapped()``.
        public subscript(observationUnwrapped fallback: ObservationFallback<Wrapped>) -> Wrapped {
            self ?? fallback.value
        }
    }
#endif
