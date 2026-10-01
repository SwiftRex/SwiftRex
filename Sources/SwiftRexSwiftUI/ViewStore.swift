// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import Combine
    import SwiftRex
    import SwiftUI

    /// The store a SwiftUI view holds — the only store you can **read**.
    ///
    /// A plain `StoreType` can only be followed (its `stateStream`) and dispatched to. A
    /// `ViewStore` adds ``state``: a ``GranularTracking`` position you read granularly, recording exactly what
    /// the view depends on. It works the same whether it signals SwiftUI through the Observation framework or
    /// Combine (its ``ViewStrategy``, chosen by whoever owns it).
    ///
    /// ```swift
    /// struct Counter: View {
    ///     let viewStore: ViewStore<CounterAction, CounterState> // a receiver: a plain `let`
    ///     var body: some View {
    ///         Text("\(viewStore.state.count)") // depends on \.count only
    ///         Button("+") { viewStore.dispatch(.increment) }
    ///     }
    /// }
    /// ```
    ///
    /// **Who owns it.** A view store keeps a snapshot and the record of what its views read, so it is built once
    /// and owned. You make it explicitly — `store.viewStore()` — and keep it with ``OwnedStore`` in the view that uses
    /// it (`@Feature`'s generated view does it for you). Views below receive it as a plain `let` — it carries its own
    /// Combine subscription, so no property wrapper is needed under either signal.
    ///
    /// **The leaf.** Composition is pure — `StoreProjection`, `StoreBuffer`,
    /// `StoreCollectionFocus`, `StoreOptionalFocus` are stages that follow a stream and keep nothing a parent
    /// holds. A view store is where that ends: it owns a snapshot (a cache) and the observation work, which are
    /// effects. Deriving a child from a view store — `viewStore.projection(…)`, or `traverse(…)` for an optional or
    /// an element — gives a pure stage built on the view store's **pure side** (its upstream), never on its snapshot;
    /// to observe that child, make its own view store (`.viewStore()`) and keep it.
    ///
    /// Bindings (`binding(.state(…).action(…))`), `transpose` and
    /// ``read(derived:id:fileID:line:column:)`` live here too: a binding SwiftUI can't observe would never
    /// update, so they don't exist on plain stores.
    @MainActor
    public struct ViewStore<Action: Sendable, State: Sendable>: StoreType, DynamicProperty {
        let reader: any TrackingReader<State>
        private let send: @MainActor (Action, ActionSource) -> Void
        /// The state over time — the **pure** side of this view store: every value its upstream delivers, forwarded
        /// from the one subscription this view store keeps (so children don't re-run the parent's chain), never gated
        /// by what its views read. Stores derived from a view store follow this. Views read ``state`` instead.
        public let stateStream: StateStream<State>
        @ObservedObject private var signal: ViewStoreSignal

        init(
            reader: any TrackingReader<State>,
            send: @escaping @MainActor (Action, ActionSource) -> Void,
            stateStream: StateStream<State>
        ) {
            self.reader = reader
            self.send = send
            self.stateStream = stateStream
            _signal = ObservedObject(wrappedValue: reader.signal)
        }

        init(engine: ViewStoreEngine<Action, State>) {
            self.init(reader: RootReader(engine: engine), send: engine.dispatch, stateStream: engine.forwardedStream)
        }

        init(_ upstream: some StoreType<Action, State>, strategy: ViewStrategy) {
            self.init(engine: ViewStoreEngine(upstream, strategy: strategy))
        }

        /// The state, read granularly: `viewStore.state.player.title` depends on `\.player.title` alone.
        public var state: GranularTracking<State> { GranularTracking(reader) }

        public func dispatch(_ action: Action, source: ActionSource) {
            send(action, source)
        }

        // MARK: - Derived reads

        /// A value computed from the state, with the view depending on **that value** (compared with `==`)
        /// instead of on the whole state — for what no key path expresses: a count, a "has any unread" flag.
        ///
        /// ```swift
        /// let hasUnread = viewStore.read(derived: { $0.messages.contains { !$0.isRead } }) // redraws on the flag only
        /// ```
        ///
        /// Closures can't be compared, so the dependency is identified by the call site plus the types involved:
        /// one call site keeps one dependency however often the body runs. When a single call site computes
        /// *different* derivations of the same type, pass a distinguishing `id`.
        public func read<T: Equatable>(
            derived compute: @escaping (State) -> T,
            id: AnyHashableSendable? = nil,
            fileID: String = #fileID,
            line: UInt = #line,
            column: UInt = #column
        ) -> T {
            read(derived: compute, types: [], id: id, site: "\(fileID):\(line):\(column)")
        }

        func read<T: Equatable>(
            derived compute: @escaping (State) -> T,
            types: [ObjectIdentifier],
            id: AnyHashableSendable?,
            site: String
        ) -> T {
            reader.read(
                derived: compute,
                id: ObservationDerivedID(site: site, types: [ObjectIdentifier(State.self), ObjectIdentifier(T.self)] + types, id: id)
            )
        }

        // MARK: - Internal reads (bindings, presentation)

        func read<T>(_ keyPath: KeyPath<State, T>) -> T { reader.read(keyPath) }

        func read<Middle, T>(_ path: KeyPath<State, Middle>, _ then: KeyPath<Middle, T>) -> T {
            reader.slice(path).read(then)
        }

        /// The value a `.state(…)` lane reads — registered on its key path when it has one, on the whole state
        /// when it's a closure or lens.
        func read<R: Relay.StateAxis.ReadsProtocol>(_ reads: R) -> R.Local where R.Global == State {
            reads.keyPath.map { reader.read($0) } ?? reads.get(reader.readWhole())
        }

        /// `then` applied to the value a `.state(…)` lane reads — registered on the composed path when the lane
        /// has a key path.
        func read<R: Relay.StateAxis.ReadsProtocol, T>(_ reads: R, _ then: KeyPath<R.Local, T>) -> T where R.Global == State {
            reads.keyPath.map { read($0, then) } ?? reads.get(reader.readWhole())[keyPath: then]
        }
    }

    // MARK: - Making a view store

    extension StoreType {
        /// A view store over this store — the one way to make one, always explicit. It builds the leaf: a snapshot,
        /// the record of what views read, and the signal to SwiftUI through `strategy` (Observation on iOS 17+,
        /// Combine below, by default).
        ///
        /// Whoever holds the result owns it, so make it where it's kept — ``OwnedStore`` in the view that uses it, a
        /// feature's view — never in a `body` (a new one per render would forget what the views read):
        ///
        /// ```swift
        /// @OwnedStore var viewStore = store.viewStore()
        /// ```
        ///
        /// On a view store it makes a **new** one, following the same pure upstream (never the first one's snapshot).
        public func viewStore(_ strategy: ViewStrategy = .automatic) -> ViewStore<Action, State> {
            ViewStore(self, strategy: strategy)
        }
    }

    // MARK: - @OwnedStore

    /// Keeps a ``ViewStore`` for as long as the view lives — nothing more. The initial value is an autoclosure,
    /// evaluated only the first time the view appears (like `@StateObject`), so re-initialising the view never
    /// rebuilds the view store:
    ///
    /// ```swift
    /// struct Root: View {
    ///     @OwnedStore var viewStore: ViewStore<AppAction, AppState>
    ///     init(store: Store<AppAction, AppState, World>) { _viewStore = OwnedStore(wrappedValue: store.viewStore()) }
    ///     var body: some View { Child(viewStore: viewStore) } // children receive `let ViewStore`
    /// }
    /// ```
    ///
    /// The signal is chosen where the view store is made: `store.viewStore(.combine)`. In a body, hand a stage to a
    /// child view and let the child keep its view store this way — a stage is a pure value, cheap to rebuild.
    @MainActor @propertyWrapper
    public struct OwnedStore<Action: Sendable, State: Sendable>: DynamicProperty {
        @StateObject private var holder: OwnedViewStore<Action, State>

        public init(wrappedValue viewStore: @autoclosure @escaping () -> ViewStore<Action, State>) {
            _holder = StateObject(wrappedValue: OwnedViewStore(viewStore()))
        }

        public var wrappedValue: ViewStore<Action, State> { holder.viewStore }
    }

    /// What `@OwnedStore` keeps in SwiftUI's state: the view store it holds. Its `objectWillChange` **is** that view
    /// store's signal (no forwarding), so under ``ViewStrategy/combine`` SwiftUI subscribes to the engine directly;
    /// under Observation it never sends.
    @MainActor
    final class OwnedViewStore<Action: Sendable, State: Sendable>: @MainActor ObservableObject {
        let viewStore: ViewStore<Action, State>
        let objectWillChange: ObservableObjectPublisher

        init(_ viewStore: ViewStore<Action, State>) {
            self.viewStore = viewStore
            objectWillChange = viewStore.reader.signal.objectWillChange
        }
    }
#endif
