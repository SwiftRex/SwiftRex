// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// The store a SwiftUI view holds — the only store you can **read**.
    ///
    /// A plain ``SwiftRex/StoreType`` can only be followed (its `stateStream`) and dispatched to. A
    /// `ViewStore` adds ``state``: a ``GranularTracking`` position you read granularly, recording exactly what
    /// the view depends on. It works the same whether it signals SwiftUI through the Observation framework or
    /// Combine (its ``ViewStrategy``, chosen by whoever owns it).
    ///
    /// ```swift
    /// struct Counter: View {
    ///     let viewStore: ViewStore<CounterAction, CounterState>       // a receiver: a plain `let`
    ///     var body: some View {
    ///         Text("\(viewStore.state.count)")                         // depends on \.count only
    ///         Button("+") { viewStore.dispatch(.increment) }
    ///     }
    /// }
    /// ```
    ///
    /// **Who owns it.** A view store keeps a snapshot and the record of what its views read, so it is built once
    /// and owned: by `@Feature`'s generated view, by ``OwnedStore`` (`@OwnedStore var viewStore = appStore`), or
    /// by ``ProjectionKeeper`` inside a body. Views below receive it as a plain `let` — it carries its own
    /// Combine subscription, so no property wrapper is needed under either signal.
    ///
    /// **Focusing.** ``focus(_:_:)`` gives a child a `ViewStore` of a key-path slice — reading through the same
    /// engine (no new subscription, no owner needed), dispatching through its own action lane.
    ///
    /// Bindings (``binding(_:dispatch:file:function:line:)`` and the dismiss-only `binding(_:dismiss:)`), `transpose` and
    /// ``read(derived:id:fileID:line:column:)`` live here too: a binding SwiftUI can't observe would never
    /// update, so they don't exist on plain stores.
    @MainActor
    public struct ViewStore<Action: Sendable, State: Sendable>: StoreType, DynamicProperty {
        let reader: any TrackingReader<State>
        private let send: @MainActor (Action, ActionSource) -> Void
        /// The state over time, as far as this view store is concerned — for stores that follow it
        /// (`viewStore.projection(…)`, a feature's view, a bridge). Views read ``state`` instead.
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
            self.init(reader: RootReader(engine: engine), send: engine.dispatch, stateStream: engine.stateStream)
        }

        /// Builds a view store over `upstream` with a new engine — whoever holds the result owns it. Views use
        /// ``OwnedStore`` / ``ProjectionKeeper`` instead, which build it once per view identity.
        init(_ upstream: some StoreType<Action, State>, strategy: ViewStrategy = .automatic) {
            self.init(engine: ViewStoreEngine(upstream, strategy: strategy))
        }

        /// The state, read granularly: `viewStore.state.player.title` depends on `\.player.title` alone.
        public var state: GranularTracking<State> { GranularTracking(reader) }

        public func dispatch(_ action: Action, source: ActionSource) {
            send(action, source)
        }

        // MARK: - Focus

        /// A key-path slice of the state, for ``focus(_:_:)`` — only key paths can be focused, since the slice
        /// reads through the parent's engine and its paths must extend the parent's.
        public struct FocusedState<Child> {
            let keyPath: KeyPath<State, Child>

            /// The slice at `keyPath`.
            public static func state(_ keyPath: KeyPath<State, Child>) -> FocusedState { FocusedState(keyPath: keyPath) }
        }

        /// A view store of a slice: it reads through this view store's engine (granularly, no new subscription —
        /// cheap to create in a body) and dispatches through `action` into this store. Hand it to a child view
        /// that reads, dispatches or binds into that slice:
        ///
        /// ```swift
        /// TransportControls(viewStore: viewStore.focus(.state(\.transport), .action(\.transport)))
        /// ```
        public func focus<A: Relay.ActionAxis.EmbedsProtocol, Child: Sendable>(
            _ state: FocusedState<Child>,
            _ action: Relay.Scope<Action, A, State, Relay.Absurd<State>, Never, Relay.Absurd<Never>>
        ) -> ViewStore<A.Local, Child> where A.Global == Action {
            let send = self.send
            let review = action.action.review
            let keyPath = state.keyPath
            return ViewStore<A.Local, Child>(
                reader: reader.slice(keyPath),
                send: { send(review($0), $1) },
                stateStream: stateStream.map { $0[keyPath: keyPath] }
            )
        }

        // MARK: - Derived reads

        /// A value computed from the state, with the view depending on **that value** (compared with `==`)
        /// instead of on the whole state — for what no key path expresses: a count, a "has any unread" flag.
        ///
        /// ```swift
        /// let hasUnread = viewStore.read(derived: { $0.messages.contains { !$0.isRead } })   // redraws on the flag only
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

    // MARK: - @OwnedStore

    /// The store a view **owns** — observes any ``SwiftRex/StoreType`` once per view identity and hands the view
    /// a ``ViewStore``.
    ///
    /// The initial value is an autoclosure, evaluated only the first time the view appears (like `@StateObject`),
    /// so re-initialising the view never rebuilds or re-subscribes the store:
    ///
    /// ```swift
    /// struct Root: View {
    ///     @OwnedStore var viewStore = appStore                       // Observation on iOS 17+, Combine below
    ///     var body: some View { Child(viewStore: viewStore) }         // children receive `let ViewStore`
    /// }
    /// ```
    ///
    /// Choose the signal with a second argument — `@OwnedStore(.combine) var viewStore = appStore` — or, when
    /// assigning in `init`, `_viewStore = OwnedStore(wrappedValue: upstream, .combine)`. Inside a body, where no
    /// property can be declared, use ``ProjectionKeeper``.
    @MainActor @propertyWrapper
    public struct OwnedStore<Action: Sendable, State: Sendable>: DynamicProperty {
        @StateObject private var engine: ViewStoreEngine<Action, State>

        public init<Upstream: StoreType>(
            wrappedValue upstream: @autoclosure @escaping () -> Upstream,
            _ strategy: ViewStrategy = .automatic
        ) where Upstream.Action == Action, Upstream.State == State {
            _engine = StateObject(wrappedValue: ViewStoreEngine(upstream(), strategy: strategy))
        }

        public var wrappedValue: ViewStore<Action, State> { ViewStore(engine: engine) }
    }
#endif
