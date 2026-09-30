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
    /// **Focusing.** `focus(_:)` gives a child a `ViewStore` of a slice — the same
    /// scope a projection takes — reading through the same engine (no new subscription, no owner needed),
    /// dispatching through its own action lane.
    ///
    /// Bindings (`binding(.state(…).action(…))`), `transpose` and
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

        /// The view store an owner hands out for `upstream`: `upstream` itself when it already **is** a view store
        /// signalling the same way (no second engine re-following the first — the router case,
        /// `Feature.view(store: viewStore.focus(…).transpose())`), a new engine over it otherwise.
        static func owning(_ upstream: any StoreType<Action, State>, strategy: ViewStrategy) -> ViewStore<Action, State> {
            if let viewStore = upstream as? ViewStore<Action, State>,
               viewStore.reader.signal.signalsThroughObservation == strategy.signalsThroughObservation {
                return viewStore
            }
            return ViewStore(engine: ViewStoreEngine(upstream, strategy: strategy))
        }

        /// The state, read granularly: `viewStore.state.player.title` depends on `\.player.title` alone.
        public var state: GranularTracking<State> { GranularTracking(reader) }

        public func dispatch(_ action: Action, source: ActionSource) {
            send(action, source)
        }

        // MARK: - Focus

        /// A view store of a slice, through the same `Relay/Scope` a projection takes — it reads through
        /// this view store's engine (no new subscription, no owner needed: cheap to create in a body) and
        /// dispatches through the scope's action lane into this store:
        ///
        /// ```swift
        /// TransportControls(viewStore: viewStore.focus(.action(\.transport).state(\.transport)))
        /// ```
        ///
        /// A key-path state lane stays granular: `\.transport` plus whatever the child reads. A closure or lens lane
        /// has no path to record, so the focused store depends on the whole state (the same fallback a binding
        /// gets).
        public func focus<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
            _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>
        ) -> ViewStore<A.Local, S.Local> where A.Global == Action, S.Global == State {
            focused(action: scope.action.review, state: scope.state)
        }

        /// Focus through a **declared** `Relay/Scope` (`ScopeOf<AppFeature>.action(…).state(…)…`) — the
        /// environment axis is ignored, so the one scope a feature declares also serves the view.
        public func focus<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol, GE, E: Relay.EnvironmentAxis.Strategy>(
            _ scope: Relay.Scope<Action, A, State, S, GE, E>
        ) -> ViewStore<A.Local, S.Local> where A.Global == Action, S.Global == State {
            focused(action: scope.action.review, state: scope.state)
        }

        private func focused<LocalAction: Sendable, R: Relay.StateAxis.ReadsProtocol>(
            action review: @escaping @Sendable (LocalAction) -> Action,
            state reads: R
        ) -> ViewStore<LocalAction, R.Local> where R.Global == State {
            let send = self.send
            return ViewStore<LocalAction, R.Local>(
                reader: reads.keyPath.map { reader.slice($0) } ?? reader.lane(reads.get),
                send: { send(review($0), $1) },
                stateStream: stateStream.map(reads.get)
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

    /// The store a view **owns** — observes any `StoreType` once per view identity and hands the view
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
    ///
    /// Handed a view store that already signals the same way (`@OwnedStore var viewStore = parentViewStore`), it
    /// reuses it instead of building a second engine that re-follows the first.
    @MainActor @propertyWrapper
    public struct OwnedStore<Action: Sendable, State: Sendable>: DynamicProperty {
        @StateObject private var holder: OwnedViewStore<Action, State>

        public init<Upstream: StoreType>(
            wrappedValue upstream: @autoclosure @escaping () -> Upstream,
            _ strategy: ViewStrategy = .automatic
        ) where Upstream.Action == Action, Upstream.State == State {
            _holder = StateObject(wrappedValue: OwnedViewStore(ViewStore.owning(upstream(), strategy: strategy)))
        }

        /// Owns a view store over a store held as an existential — `any StoreType<Action, State>`, the usual type of
        /// an app's store property. Assign it in `init`: `_viewStore = OwnedStore(store)`. (A property wrapper's
        /// `wrappedValue` initializer can't take an existential, so this form has no label.)
        public init(
            _ upstream: @autoclosure @escaping () -> any StoreType<Action, State>,
            _ strategy: ViewStrategy = .automatic
        ) {
            _holder = StateObject(wrappedValue: OwnedViewStore(ViewStore.owning(upstream(), strategy: strategy)))
        }

        public var wrappedValue: ViewStore<Action, State> { holder.viewStore }
    }

    /// What `@OwnedStore` keeps in SwiftUI's state: the view store it owns — a new engine, or a view store it was
    /// handed. Its `objectWillChange` **is** that view store's signal (no forwarding), so under
    /// ``ViewStrategy/combine`` SwiftUI subscribes to the engine directly; under Observation it never sends.
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
