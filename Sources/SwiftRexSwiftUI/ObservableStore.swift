// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import Combine
    #if canImport(Observation)
        import Observation
    #endif
    import SwiftRex

    /// The store a SwiftUI view observes — wraps any ``StoreType`` and invalidates **only the views that read
    /// what changed**, down to any depth of the state tree.
    ///
    /// State stays a plain struct where it lives: the store keeps one snapshot of it (refreshed once per
    /// upstream change, so a projection's `map` runs once per change however many views read it) and
    /// records, per key path, what the views read. A read is granular by default:
    ///
    /// ```swift
    /// let store = appStore.observable()
    /// Text(store.player.title)        // depends on \.player.title only
    /// PlayheadView(node: store.player) // a StateNode — the child reads deeper paths itself
    /// ```
    ///
    /// `store.player` is a ``StateNode`` (the walk continues) unless `Player` is an ``ObservableLeaf`` (read
    /// whole). On each upstream change the store compares every recorded path between the old and new
    /// snapshot — with `==` when the value is `Equatable`, as `@Observable` does — and signals only the ones
    /// that differ. The ``ViewStrategy`` picks the signal:
    ///
    /// - ``ViewStrategy/observation`` (iOS 17+): Observation-framework invalidation per changed path. Hold
    ///   the store as a plain `let`/`@State`.
    /// - ``ViewStrategy/combine`` (iOS 13+): a single `objectWillChange`, sent only when some path a view
    ///   read has changed. Hold the store as `@ObservedObject`/`@StateObject`.
    ///
    /// `ObservableStore` is itself a ``StoreType`` whose own ``observe(willChange:didChange:)`` fires only
    /// when its snapshot changed (by `==` when `State` is `Equatable`), so a store observed or projected
    /// from it is woken only by changes that reached it.
    ///
    /// Bindings and presentation helpers (``ObservableStoreType/binding(_:dispatch:file:function:line:)``,
    /// ``ObservableStoreType/presence(_:dismiss:file:function:line:)-(_,_,_,_,_)``, `presenting`) exist only on
    /// observable stores: calling them on a plain `Store` or `StoreProjection` doesn't compile.
    @MainActor
    public final class ObservableStore<Action: Sendable, State: Sendable>: ObservableObject, ObservableStoreType {
        public typealias RootAction = Action
        public typealias RootState = State

        /// How this store signals SwiftUI.
        public let strategy: ViewStrategy

        /// The latest state, refreshed once per upstream change.
        private(set) var snapshot: State

        /// A reference to itself — every observable store is rooted in an `ObservableStore`.
        public var root: ObservableStore<Action, State> { self }
        /// The identity path — this store's state *is* the root state.
        public let prefix: KeyPath<State, State> = \State.self
        /// The identity embedding — this store's actions *are* the root actions.
        public let embed: @Sendable (Action) -> Action = { $0 }

        let paths = ObservationPaths()

        private let upstream: any StoreType<Action, State>
        private var token: SubscriptionToken?
        // An `ObservationRegistrar` where the Observation framework is available and chosen; `nil` otherwise.
        private let registrar: (any Sendable)?

        typealias Dependency = ObservationDependency<ObservableStore, State>

        // Dependencies by key-path instance (the fast path — literal and cached paths are unique instances),
        // and by key-path value (so equal paths built separately share one dependency).
        private var fastDependencies: [ObjectIdentifier: Dependency] = [:]
        // Keeps every instance keyed in `fastDependencies` alive, so its ObjectIdentifier can't be reused.
        private var fastKeys: [AnyKeyPath] = []
        private var dependencies: [AnyKeyPath: Dependency] = [:]
        private let registry = ObservationRegistry<ObservableStore, State>()
        private var sweepThreshold = ObservableStore.minimumSweepThreshold

        private var observers: [UInt64: (willChange: @MainActor @Sendable () -> Void,
                                         didChange: @MainActor @Sendable () -> Void)] = [:]
        private var nextObserverKey: UInt64 = 0
        private lazy var wholeChanged: (State, State) -> Bool = ObservableStore.comparator(prefix)

        /// Wraps `upstream`, observing it through `strategy` (``ViewStrategy/observation`` by default; on an OS
        /// without the Observation framework the store falls back to ``ViewStrategy/combine`` signalling).
        public init(_ upstream: some StoreType<Action, State>, strategy: ViewStrategy = .observation) {
            self.upstream = upstream
            self.strategy = strategy
            snapshot = upstream.state
            registrar = ObservableStore.makeRegistrar(strategy)
            token = upstream.observe(didChange: { [weak self] in self?.receive(upstream.state) })
        }

        // MARK: - StoreType

        /// The whole state — a coarse read: the view depends on **every** change. Prefer reading the path you
        /// need (`store.title`, `store.player.position`) so the view depends on that alone.
        public var state: State { read(prefix) }

        public func dispatch(_ action: Action, source: ActionSource) {
            upstream.dispatch(action, source: source)
        }

        /// Registers callbacks that fire only when this store's snapshot changed — by `==` when `State` is
        /// `Equatable`, on every upstream change that reached it otherwise.
        public func observe(
            willChange: @escaping @MainActor @Sendable () -> Void,
            didChange: @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken {
            let id = nextObserverKey
            nextObserverKey &+= 1
            observers[id] = (willChange: willChange, didChange: didChange)
            return SubscriptionToken { [weak self] in
                Task { @MainActor [weak self] in self?.observers.removeValue(forKey: id) }
            }
        }

        // MARK: - ObservableStoreType

        /// Reads `keyPath`, recording it as a dependency of whoever is reading (a SwiftUI body).
        public func read<T>(_ keyPath: KeyPath<State, T>) -> T {
            let dependency = fastDependencies[ObjectIdentifier(keyPath)] ?? resolve(keyPath)
            if !dependency.armed { registry.arm(dependency) }
            dependency.access?(self)
            return snapshot[keyPath: keyPath]
        }

        /// Reads `keyPath` without recording a dependency.
        public func peek<T>(_ keyPath: KeyPath<State, T>) -> T {
            snapshot[keyPath: keyPath]
        }

        // MARK: - Change propagation

        private func receive(_ new: State) {
            guard !registry.isEmpty || !observers.isEmpty else {
                snapshot = new
                return
            }
            let old = snapshot
            let fired = registry.diff(old, new)
            if registrar == nil {
                if !fired.isEmpty {
                    objectWillChange.send()
                    registry.disarmAll()
                }
                snapshot = new
            } else {
                fired.forEach { $0.willSet?(self) }
                snapshot = new
                fired.forEach { $0.didSet?(self) }
            }
            guard !observers.isEmpty, !fired.isEmpty || wholeChanged(old, new) else { return }
            observers.values.forEach { $0.willChange() }
            observers.values.forEach { $0.didChange() }
        }

        // MARK: - Registry

        private static var minimumSweepThreshold: Int { 1_024 }

        var armedCount: Int { registry.armedCount }

        fileprivate func resolve<T>(_ keyPath: KeyPath<State, T>) -> Dependency {
            if fastKeys.count + paths.count > sweepThreshold { sweep() }
            let dependency = dependencies[keyPath] ?? makeDependency(keyPath)
            dependencies[keyPath] = dependency
            fastDependencies[ObjectIdentifier(keyPath)] = dependency
            fastKeys.append(keyPath)
            return dependency
        }

        // Drops dependencies outside the live tree and every cached composition; both are rebuilt on demand.
        // Keeps the registry bounded when paths churn — e.g. rows of a long-lived list.
        private func sweep() {
            dependencies = dependencies.filter { $0.value.attached }
            fastDependencies.removeAll(keepingCapacity: true)
            fastKeys.removeAll(keepingCapacity: true)
            paths.removeAll()
            sweepThreshold = max(ObservableStore.minimumSweepThreshold, dependencies.count * 4)
        }

        private func makeDependency<T>(_ keyPath: KeyPath<State, T>) -> Dependency {
            let storeKey = (\ObservableStore<Action, State>.snapshot).appending(path: keyPath)
            let tracking = ObservableStore.tracking(registrar, storeKey)
            return Dependency(
                changed: ObservableStore.comparator(keyPath),
                parent: paths.parentGuard(of: keyPath, in: self) as? Dependency,
                access: tracking?.access,
                willSet: tracking?.willSet,
                didSet: tracking?.didSet
            )
        }

        /// `!=` when the value is `Equatable` (resolved once, when the path is first read), otherwise
        /// "always changed" — the same rule `@Observable` uses.
        static func comparator<T>(_ keyPath: KeyPath<State, T>) -> (State, State) -> Bool {
            (T.self as? any Equatable.Type).map { comparator($0, keyPath) } ?? { _, _ in true }
        }

        private static func comparator<E: Equatable, T>(_: E.Type, _ keyPath: KeyPath<State, T>) -> (State, State) -> Bool {
            (keyPath as? KeyPath<State, E>).map { typed in { $0[keyPath: typed] != $1[keyPath: typed] } } ?? { _, _ in true }
        }

        private typealias Tracking = (
            access: (ObservableStore) -> Void,
            willSet: (ObservableStore) -> Void,
            didSet: (ObservableStore) -> Void
        )

        private static func makeRegistrar(_ strategy: ViewStrategy) -> (any Sendable)? {
            #if canImport(Observation)
                guard strategy == .observation, #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else { return nil }
                return ObservationRegistrar()
            #else
                return nil
            #endif
        }

        private static func tracking<T>(_ registrar: (any Sendable)?, _ storeKey: KeyPath<ObservableStore, T>) -> Tracking? {
            #if canImport(Observation)
                guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
                      let registrar = registrar as? ObservationRegistrar else { return nil }
                return (
                    access: { registrar.access($0, keyPath: storeKey) },
                    willSet: { registrar.willSet($0, keyPath: storeKey) },
                    didSet: { registrar.didSet($0, keyPath: storeKey) }
                )
            #else
                return nil
            #endif
        }
    }

    extension ObservableStore: ObservationGuardResolver {
        // The dependency on a composed path's parent — only for paths rooted at this store's state.
        func guardDependency<Root, Value>(_ path: KeyPath<Root, Value>) -> AnyObject? {
            (path as? KeyPath<State, Value>).map(resolve)
        }
    }

    #if canImport(Observation)
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        extension ObservableStore: Observable {}
    #endif

    extension StoreType {
        /// Wraps this store in an ``ObservableStore`` — the store a SwiftUI view observes, granular per key
        /// path. Works on any store: the real `Store` (identity — no projection needed just to observe),
        /// a projection, a buffer, or another observable store.
        ///
        /// ```swift
        /// @State var root = appStore.observable()                        // iOS 17+, Observation
        /// @StateObject var root = appStore.observable(.combine)          // iOS 13+, Combine
        /// let screen = appStore.buffer().projection(action: …, state: mapState).observable()
        /// ```
        public func observable(_ strategy: ViewStrategy = .observation) -> ObservableStore<Action, State> {
            ObservableStore(self, strategy: strategy)
        }
    }
#endif
