// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// A position in a view store's state — what `viewStore.state` is, and what reading into it gives you until
    /// you reach a value.
    ///
    /// Reading through it is **granular**: `viewStore.state.player.title` makes the reading view depend on
    /// `\.player.title` alone (compared with `==`), however deep. Each hop is another `GranularTracking`; nothing
    /// is recorded until you reach a type conforming to ``IndivisibleTracking`` (strings, numbers, `Bool`, …,
    /// read whole) or ask for ``value``:
    ///
    /// ```swift
    /// Text(viewStore.state.player.title)        // String — depends on \.player.title
    /// viewStore.state.player                    // GranularTracking<Player> — nothing recorded yet
    /// viewStore.state.player.value              // the whole Player — depends on \.player
    /// ```
    ///
    /// Formally it is a *getter* optic built from key paths (appending paths composes it), whose application also
    /// **records** the path it reads — which is why it's built on key paths rather than closures: the path is the
    /// dependency's identity.
    ///
    /// **Pass nodes to subviews that only read.** The child then depends only on what *it* reads, so a field that
    /// changes ten times a second redraws the one small view that shows it:
    ///
    /// ```swift
    /// Console(mixer: viewStore.state.mixer)      // let mixer: GranularTracking<Mixer>
    /// Playhead(transport: viewStore.state.transport)
    /// ```
    ///
    /// A `DynamicProperty`: stored in a view, it also carries the view store's Combine signal, so a plain `let`
    /// redraws under ``ViewStrategy/combine`` too. Its own members (`value`, `each`, `isPresent()`, `unwrapped()`,
    /// `id`) hide state fields with the same name.
    @MainActor @dynamicMemberLookup
    public struct GranularTracking<Value>: DynamicProperty {
        let reader: any TrackingReader<Value>
        @ObservedObject private var signal: ViewStoreSignal

        init(_ reader: any TrackingReader<Value>) {
            self.reader = reader
            _signal = ObservedObject(wrappedValue: reader.signal)
        }

        /// The whole value at this position — the reader depends on any change to it (by `==` when `Equatable`).
        public var value: Value { reader.readWhole() }

        /// A member read whole — the reader depends on this path alone, compared with `==`.
        public subscript<T: IndivisibleTracking>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
            reader.read(keyPath)
        }

        /// A member read granularly — a deeper position.
        public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> GranularTracking<T> {
            GranularTracking<T>(reader.slice(keyPath))
        }

        /// One position per element of an `Identifiable` collection, for `ForEach`. The calling body depends only on
        /// the **ids** (insert / remove / reorder); each row depends only on what it reads from its own element.
        ///
        /// ```swift
        /// ForEach(viewStore.state.each(\.songs)) { song in SongRow(song: song) }
        /// ```
        public func each<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<Value, C>
        ) -> [GranularTracking<C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
            reader.rows(keyPath).map(GranularTracking<C.Element>.init)
        }
    }

    extension GranularTracking: @MainActor Identifiable where Value: Identifiable {
        /// The element's id, read without recording a dependency (rows are keyed by id already).
        public var id: Value.ID { reader.peek(\Value.id) }
    }

    extension GranularTracking {
        /// `true` while the optional is `.some` — the reader depends on the presence edge only.
        public func isPresent<Wrapped>() -> Bool where Value == Wrapped? {
            reader.read(\Wrapped?.observationIsPresent)
        }

        /// The position of the wrapped value while `.some`, `nil` otherwise. The check depends on the presence
        /// edge only; reads through the returned position depend on what they read.
        public func unwrapped<Wrapped: Sendable>() -> GranularTracking<Wrapped>? where Value == Wrapped? {
            isPresent()
                ? reader.peekWhole().map { current in
                    GranularTracking<Wrapped>(reader.slice(\Wrapped?.[observationUnwrapped: ObservationFallback(current)]))
                }
                : nil
        }
    }

    // MARK: - Readers (internal): where a position reads from, with the engine's root type hidden

    /// Reads rooted at `Base`, whatever the engine's state type is. A view store or a position holds one of these;
    /// the root type appears only in the concrete readers.
    @MainActor
    protocol TrackingReader<Base> {
        associatedtype Base

        var signal: ViewStoreSignal { get }
        func read<T>(_ keyPath: KeyPath<Base, T>) -> T
        func peek<T>(_ keyPath: KeyPath<Base, T>) -> T
        func readWhole() -> Base
        func peekWhole() -> Base
        func slice<T>(_ keyPath: KeyPath<Base, T>) -> any TrackingReader<T>
        func read<T: Equatable>(derived compute: @escaping (Base) -> T, id: ObservationDerivedID) -> T
        func rows<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<Base, C>
        ) -> [any TrackingReader<C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable
    }

    /// The engine's whole state.
    @MainActor
    struct RootReader<Action: Sendable, State: Sendable>: TrackingReader {
        let engine: ViewStoreEngine<Action, State>

        var signal: ViewStoreSignal { engine }
        func read<T>(_ keyPath: KeyPath<State, T>) -> T { engine.read(keyPath) }
        func peek<T>(_ keyPath: KeyPath<State, T>) -> T { engine.peek(keyPath) }
        func readWhole() -> State { engine.read(engine.whole) }
        func peekWhole() -> State { engine.snapshot }

        func slice<T>(_ keyPath: KeyPath<State, T>) -> any TrackingReader<T> {
            SliceReader(engine: engine, prefix: keyPath)
        }

        func read<T: Equatable>(derived compute: @escaping (State) -> T, id: ObservationDerivedID) -> T {
            engine.read(ObservationDerivedKey(id: id, compute: compute))
        }

        func rows<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<State, C>
        ) -> [any TrackingReader<C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
            _ = engine.read(engine.paths.append(keyPath, \C.observationIDs))
            return engine.paths.rows(keyPath, in: engine.peek(keyPath)).map { SliceReader(engine: engine, prefix: $0) }
        }
    }

    /// A key-path position inside the engine's state.
    @MainActor
    struct SliceReader<Action: Sendable, Root: Sendable, Base>: TrackingReader {
        let engine: ViewStoreEngine<Action, Root>
        let prefix: KeyPath<Root, Base>

        var signal: ViewStoreSignal { engine }
        func read<T>(_ keyPath: KeyPath<Base, T>) -> T { engine.read(engine.paths.append(prefix, keyPath)) }
        func peek<T>(_ keyPath: KeyPath<Base, T>) -> T { engine.peek(prefix)[keyPath: keyPath] }
        func readWhole() -> Base { engine.read(prefix) }
        func peekWhole() -> Base { engine.peek(prefix) }

        func slice<T>(_ keyPath: KeyPath<Base, T>) -> any TrackingReader<T> {
            SliceReader<Action, Root, T>(engine: engine, prefix: engine.paths.append(prefix, keyPath))
        }

        func read<T: Equatable>(derived compute: @escaping (Base) -> T, id: ObservationDerivedID) -> T {
            let prefix = self.prefix
            return engine.read(ObservationDerivedKey(
                id: ObservationDerivedID(site: id.site, types: id.types + [ObjectIdentifier(prefix)], id: id.id),
                compute: { compute($0[keyPath: prefix]) }
            ))
        }

        func rows<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<Base, C>
        ) -> [any TrackingReader<C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
            let collection = engine.paths.append(prefix, keyPath)
            _ = engine.read(engine.paths.append(collection, \C.observationIDs))
            return engine.paths.rows(collection, in: engine.peek(collection)).map { SliceReader<Action, Root, C.Element>(engine: engine, prefix: $0) }
        }
    }

    // MARK: - Unwrapping plumbing

    /// A key-path argument carrying a fallback value that doesn't take part in equality — so the path stays the
    /// same dependency whatever the fallback. Observation plumbing behind ``GranularTracking/unwrapped()``.
    public struct ObservationFallback<Value: Sendable>: Hashable, Sendable {
        let value: Value

        init(_ value: Value) { self.value = value }

        public static func == (lhs: Self, rhs: Self) -> Bool { true }
        public func hash(into hasher: inout Hasher) {}
    }

    extension Optional where Wrapped: Sendable {
        /// The wrapped value, or the fallback once `nil` (a position can outlive its value for a frame).
        /// Observation plumbing behind ``GranularTracking/unwrapped()``.
        public subscript(observationUnwrapped fallback: ObservationFallback<Wrapped>) -> Wrapped {
            self ?? fallback.value
        }
    }
#endif
