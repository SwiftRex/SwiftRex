// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex

    /// A store a SwiftUI view can **observe** — reads through it register as dependencies of the reading
    /// body, so the view redraws when (and only when) something it read changes.
    ///
    /// The conformers are ``ObservableStore`` (the root: it owns the snapshot and the registry) and
    /// ``ScopedStore`` (a key-path slice of an observable store with its own action lane). The plain
    /// ``StoreType``s — `Store`, `StoreProjection`, `StoreBuffer` — are **not** observable; wrap one with
    /// ``SwiftRex/StoreType/observable(_:)`` to hand it to a view. That's also why the binding and presentation
    /// helpers live here: a binding over a store SwiftUI can't observe never updates, so it doesn't compile.
    ///
    /// Reads are granular by default through dynamic member lookup:
    ///
    /// ```swift
    /// store.title             // String — an ObservableLeaf, read whole; depends on \.title
    /// store.player            // StateNode<…, Player> — the walk continues
    /// store.player.position   // Double; depends on \.player.position only
    /// store.player.value      // Player — the whole value; depends on \.player
    /// ForEach(store.each(\.rows)) { row in RowView(row: row) }   // one dependency per row
    /// ```
    ///
    /// A `State` member whose name clashes with a store member (`state`, `dispatch`, `observe`, `read`,
    /// `each`, `binding`, `presence`, `item`, …) is shadowed by it — read it as `store.read(\.state)`.
    @MainActor @dynamicMemberLookup
    public protocol ObservableStoreType<Action, State>: StoreType {
        /// The action type of the root ``ObservableStore``.
        associatedtype RootAction: Sendable
        /// The state type of the root ``ObservableStore``.
        associatedtype RootState: Sendable

        /// The observable store every read registers on.
        var root: ObservableStore<RootAction, RootState> { get }

        /// Where this store's state sits inside the root's.
        var prefix: KeyPath<RootState, State> { get }

        /// How this store's actions reach the root.
        var embed: @Sendable (Action) -> RootAction { get }

        /// Reads `keyPath`, recording it as a dependency of whoever is reading (a SwiftUI body).
        func read<T>(_ keyPath: KeyPath<State, T>) -> T

        /// Reads `keyPath` **without** recording a dependency — for action handlers and other code that runs
        /// outside a body.
        func peek<T>(_ keyPath: KeyPath<State, T>) -> T
    }

    extension ObservableStoreType {
        public func read<T>(_ keyPath: KeyPath<State, T>) -> T {
            root.read(root.paths.append(prefix, keyPath))
        }

        public func peek<T>(_ keyPath: KeyPath<State, T>) -> T {
            root.peek(root.paths.append(prefix, keyPath))
        }

        /// Reads `then` inside the value at `path`, recording the composed path (`path` + `then`) as the
        /// dependency. The composition is cached, so repeated reads stay cheap.
        public func read<Middle, T>(_ path: KeyPath<State, Middle>, _ then: KeyPath<Middle, T>) -> T {
            read(root.paths.append(path, then))
        }

        // MARK: - Granular reads

        /// A leaf member, read whole — the view depends on this path alone, compared with `==`.
        public subscript<T: ObservableLeaf>(dynamicMember keyPath: KeyPath<State, T>) -> T {
            read(keyPath)
        }

        /// A non-leaf member, as a ``StateNode`` — keep reading into it; nothing is recorded until a leaf (or
        /// ``StateNode/value``) is read.
        public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> StateNode<Self, T> {
            StateNode(source: self, path: keyPath)
        }

        /// One ``StateNode`` per element of an `Identifiable` collection, for `ForEach`. The calling body
        /// depends only on the **ids** (redraws on insert / remove / reorder); each row depends only on what
        /// it reads from its own element.
        ///
        /// ```swift
        /// ForEach(store.each(\.songs)) { song in SongRow(song: song) }   // SongRow reads song.title, …
        /// ```
        public func each<C: RandomAccessCollection & Sendable>(
            _ keyPath: KeyPath<State, C>
        ) -> [StateNode<Self, C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
            _ = read(keyPath, \C.observationIDs)
            return root.paths.rows(keyPath, in: peek(keyPath)).map { StateNode(source: self, path: $0) }
        }

        // MARK: - Reading through a state lane

        /// The value a `.state(…)` lane reads — registered on the lane's key path when it has one, on the whole
        /// state when it's a closure or lens.
        public func read<R: Relay.StateAxis.ReadsProtocol>(_ reads: R) -> R.Local where R.Global == State {
            reads.keyPath.map { read($0) } ?? reads.get(state)
        }

        /// `then` applied to the value a `.state(…)` lane reads — registered on the composed path when the lane
        /// has a key path, so e.g. a presence check depends on the presence edge only.
        public func read<R: Relay.StateAxis.ReadsProtocol, T>(
            _ reads: R,
            _ then: KeyPath<R.Local, T>
        ) -> T where R.Global == State {
            reads.keyPath.map { read($0, then) } ?? reads.get(state)[keyPath: then]
        }
    }
#endif
