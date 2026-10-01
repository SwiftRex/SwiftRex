// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import Combine
    #if canImport(Observation)
        import Observation
    #endif
    import SwiftRex

    /// The Combine signal of a view store, as one concrete, non-generic type — so a `ViewStore`, a
    /// `GranularTracking` node, any view holding either, can subscribe to it through `@ObservedObject`
    /// whatever the engine's state type. Only engines using the ``ViewStrategy/combine`` signal (or
    /// ``ViewStrategy/automatic`` below iOS 17) ever send on it.
    @MainActor
    class ViewStoreSignal: ObservableObject {
        /// Whether this view store signals through the Observation framework (else Combine).
        var signalsThroughObservation: Bool { false }
    }

    extension ViewStrategy {
        /// What this strategy resolves to on this OS: the Observation framework, or Combine.
        var signalsThroughObservation: Bool {
            #if canImport(Observation)
                guard self != .combine, #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else { return false }
                return true
            #else
                return false
            #endif
        }
    }

    /// What makes a `ViewStore` observable: one snapshot of the upstream's state, the dependencies views
    /// recorded while reading it, and the signal that tells SwiftUI when one of them changed.
    ///
    /// - It **follows** its upstream through `stateStream` — pushed values only, it never reads the upstream.
    /// - On each new state it compares only the recorded dependencies (a tree: an unchanged parent path skips
    ///   everything beneath it) and signals the changed ones: per path through the Observation registrar, or
    ///   one `objectWillChange` under Combine. The "will change" moment happens here, against the stale
    ///   snapshot SwiftUI can still read to prepare animations.
    /// - Its own `stateStream` passes a state on only when something changed, so stores that follow a view
    ///   store are woken only by changes that reached it.
    @MainActor
    final class ViewStoreEngine<Action: Sendable, State: Sendable>: ViewStoreSignal {
        typealias Dependency = ObservationDependency<ViewStoreEngine, State>

        let strategy: ViewStrategy
        let paths = ObservationPaths()
        /// The identity path — reads of the whole state register on it.
        let whole: KeyPath<State, State> = \State.self

        /// The latest state, replaced once per upstream change.
        private(set) var snapshot: State

        private let send: @MainActor (Action, ActionSource) -> Void
        private var token: UISubscriptionToken?
        // An `ObservationRegistrar` where the Observation framework is available and chosen; `nil` otherwise.
        private let registrar: (any Sendable)?

        // Dependencies by key-path instance (the fast path — literal and cached paths are unique instances),
        // and by key-path value (so equal paths built separately share one dependency).
        private var fastDependencies: [ObjectIdentifier: Dependency] = [:]
        // Keeps every instance keyed in `fastDependencies` alive, so its ObjectIdentifier can't be reused.
        private var fastKeys: [AnyKeyPath] = []
        private var dependencies: [AnyKeyPath: Dependency] = [:]
        private let registry = ObservationRegistry<ViewStoreEngine, State>()
        private var sweepThreshold = ViewStoreEngine.minimumSweepThreshold

        // Stages derived from this view store (`viewStore.projection(…)`, `each`, `traverse`, a bridge) follow the
        // upstream values this engine already receives — forwarded as they arrive, never gated by what the views
        // read — so the parent's chain runs once per change however many children follow it. Only their
        // callbacks are kept, and each child's token removes its own.
        private var followers: [Int: @MainActor (State) -> Void] = [:]
        private var nextFollower = 0
        // The hints this view store's own element-presence reads keep (`traverse(_:element:)`) — observation state
        // of this leaf, keyed by call site + element id; never held for a child.
        private var elementHints: [AnyHashable: ElementHint] = [:]

        /// Follows `upstream`, signalling SwiftUI through `strategy`.
        init(_ upstream: some StoreType<Action, State>, strategy: ViewStrategy) {
            let inbox = Inbox<State>()
            let (current, token) = upstream.stateStream.subscribe { inbox.receive($0) }
            self.strategy = strategy
            snapshot = current
            send = { action, source in upstream.dispatch(action, source: source) }
            registrar = ViewStoreEngine.makeRegistrar(strategy)
            self.token = token
            super.init()
            inbox.target = { [weak self] in self?.receive($0) }
        }

        /// The upstream's state over time — the **pure** side of a view store, forwarded from this engine's one
        /// subscription. Never the snapshot's observation: what the views read doesn't gate it.
        var forwardedStream: StateStream<State> {
            StateStream { [self] onChange in
                let key = nextFollower
                nextFollower += 1
                followers[key] = onChange
                return (snapshot, UISubscriptionToken { [weak self] in self?.followers[key] = nil })
            }
        }

        func dispatch(_ action: Action, source: ActionSource) {
            send(action, source)
        }

        /// The hint kept for one element-presence read of this view store.
        func elementHint(_ key: AnyHashable) -> ElementHint {
            if let hint = elementHints[key] { return hint }
            let hint = ElementHint()
            elementHints[key] = hint
            return hint
        }

        // MARK: - Reads

        /// Reads `keyPath`, recording it as a dependency of whoever is reading (a SwiftUI body).
        func read<T>(_ keyPath: KeyPath<State, T>) -> T {
            let dependency = fastDependencies[ObjectIdentifier(keyPath)] ?? resolve(keyPath)
            if !dependency.armed { registry.arm(dependency) }
            dependency.access?(self)
            return snapshot[keyPath: keyPath]
        }

        /// Reads `keyPath` without recording a dependency — internal plumbing (ids, fallbacks), never offered
        /// to views.
        func peek<T>(_ keyPath: KeyPath<State, T>) -> T {
            snapshot[keyPath: keyPath]
        }

        /// Reads a value derived from the state, recording a dependency on **that value** (compared with `==`).
        func read<T: Equatable>(_ key: ObservationDerivedKey<State, T>) -> T {
            let storeKey = \ViewStoreEngine<Action, State>.[derived: key]
            let dependency = dependencies[storeKey] ?? makeDerivedDependency(storeKey, key)
            dependencies[storeKey] = dependency
            if !dependency.armed { registry.arm(dependency) }
            dependency.access?(self)
            return key.compute(snapshot)
        }

        subscript<T>(derived key: ObservationDerivedKey<State, T>) -> T {
            key.compute(snapshot)
        }

        var armedCount: Int { registry.armedCount }

        // MARK: - Change propagation

        private func receive(_ new: State) {
            // Sweep between bodies, never during one: a sweep mid-body would drop the parent links of the paths it
            // is still reading, and every row read after it would become a root compared on every change.
            if fastKeys.count + paths.count > sweepThreshold { sweep() }
            update(new)
            forward(new)
        }

        private func forward(_ new: State) {
            guard !followers.isEmpty else { return }
            for key in Array(followers.keys) { followers[key]?(new) } // a follower may leave while others are called
        }

        private func update(_ new: State) {
            guard !registry.isEmpty else {
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
        }

        // MARK: - Registry

        private static var minimumSweepThreshold: Int { 1_024 }

        fileprivate func resolve<T>(_ keyPath: KeyPath<State, T>) -> Dependency {
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
            elementHints.removeAll(keepingCapacity: true)
            sweepThreshold = max(ViewStoreEngine.minimumSweepThreshold, dependencies.count * 4)
        }

        private func makeDependency<T>(_ keyPath: KeyPath<State, T>) -> Dependency {
            let storeKey = (\ViewStoreEngine<Action, State>.snapshot).appending(path: keyPath)
            let tracking = ViewStoreEngine.tracking(registrar, storeKey)
            return Dependency(
                changed: ViewStoreEngine.comparator(keyPath),
                parent: paths.parentGuard(of: keyPath, in: self) as? Dependency,
                access: tracking?.access,
                willSet: tracking?.willSet,
                didSet: tracking?.didSet
            )
        }

        private func makeDerivedDependency<T: Equatable>(
            _ storeKey: KeyPath<ViewStoreEngine, T>,
            _ key: ObservationDerivedKey<State, T>
        ) -> Dependency {
            let tracking = ViewStoreEngine.tracking(registrar, storeKey)
            return Dependency(
                changed: { key.compute($0) != key.compute($1) },
                parent: nil,
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
            access: (ViewStoreEngine) -> Void,
            willSet: (ViewStoreEngine) -> Void,
            didSet: (ViewStoreEngine) -> Void
        )

        override var signalsThroughObservation: Bool { registrar != nil }

        private static func makeRegistrar(_ strategy: ViewStrategy) -> (any Sendable)? {
            #if canImport(Observation)
                guard strategy.signalsThroughObservation, #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else { return nil }
                return ObservationRegistrar()
            #else
                return nil
            #endif
        }

        private static func tracking<T>(_ registrar: (any Sendable)?, _ storeKey: KeyPath<ViewStoreEngine, T>) -> Tracking? {
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

    extension ViewStoreEngine: ObservationGuardResolver {
        // The dependency on a composed path's parent — only for paths rooted at this engine's state.
        func guardDependency<Root, Value>(_ path: KeyPath<Root, Value>) -> AnyObject? {
            (path as? KeyPath<State, Value>).map(resolve)
        }
    }

    #if canImport(Observation)
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        extension ViewStoreEngine: Observable {}
    #endif

    // Routes upstream values to the engine once it exists (the upstream hands over its current value before
    // `self` is initialised, and later values arrive through here).
    @MainActor
    private final class Inbox<State> {
        var target: ((State) -> Void)?
        func receive(_ value: State) { target?(value) }
    }
#endif
