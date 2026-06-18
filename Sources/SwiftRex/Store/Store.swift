import CoreFP
import DataStructure
import Foundation
import Hourglass

/// The sole owner of mutable `State` and the central coordinator of the three-phase dispatch pipeline.
///
/// Create one `Store` per application and pass it — or narrowed ``StoreProjection`` values — to
/// your features. The ``Store`` is `@MainActor`, so all state reads, mutations, and observer
/// notifications happen on the main thread without any manual actor-hopping.
///
/// ## Three-phase dispatch
///
/// Every dispatched action runs through four steps in `runPhases`:
///
/// ```
/// 1. behavior.handle(action, stateAccess)    — all Behaviors; stateAccess = pre-mutation state
/// 2. stateObservers.willChange fired         — ObservableObject fires objectWillChange here
///    consequence.mutation.runEndoMut(&state)  — zero-copy inout; refcount stays at 1
///    stateObservers.didChange fired           — @Observable / push-based observers
/// 3. consequence.effect.runReader(env)        — Reader runs; stateAccess = post-mutation state
/// 4. schedule(component) per Effect.Component — per-component EffectScheduling applied
/// ```
///
/// Grouping all `willChange` notifications before the mutation (and all `didChange` notifications
/// after) means observers never see a partially-mutated state. `withAnimation { store.dispatch(...) }`
/// works correctly because SwiftUI animation transactions are thread-local and the mutation lands
/// on `@MainActor` inside the transaction.
///
/// ## Serialized, never-nested processing
///
/// Actions are serialized through a FIFO `queue` guarded by an `isProcessing` flag, so
/// `runPhases` never runs nested. A synchronous ``dispatch(_:source:)`` runs its action — and
/// any actions dispatched synchronously while it runs (for example a `didChange` observer that
/// re-dispatches) — within the same run loop turn, draining the queue in order. Because the
/// pipeline is never re-entered mid-action, observers always see a fully-committed state.
///
/// Actions produced by effects re-enter through a `Task` hop (see `makeSend`), so they are
/// always processed on a later turn rather than inline — keeping effect work off the run loop
/// turn that drove the original UI dispatch.
///
/// ## Initialisation
///
/// Three convenience initialisers cover common patterns:
///
/// ```swift
/// // Full form: custom Behavior, any Environment
/// let store = Store(
///     initial: AppState.initial,
///     behavior: appBehavior,
///     environment: AppEnvironment.live
/// )
///
/// // Reducer only (Environment == Void, no side effects)
/// let store = Store(
///     initial: CounterState(),
///     reducer: counterReducer
/// )
///
/// // Separate Reducer + Middleware (composed internally)
/// let store = Store(
///     initial: AppState.initial,
///     reducer: appReducer,
///     middleware: appMiddleware,
///     environment: AppEnvironment.live
/// )
/// ```
///
/// ## Effect lifecycle
///
/// Each `Effect.Component` is tracked in `effects: [AnyHashableSendable: SubscriptionToken]`.
/// Anonymous (`.immediately`) components use a `UUID` key that is removed on `complete`.
/// Named components (`.replacing`, `.debounce`, `.throttle`) use the caller-supplied id.
///
/// ``SubscriptionToken`` cancels on release, so the registry behaves like a `Set<AnyCancellable>`:
/// replacing the token under a key cancels the effect it displaced, and deallocating the Store
/// releases the whole dictionary, cancelling every in-flight effect — no explicit `deinit` is needed.
///
/// Dispatching from inside an effect re-enters the pipeline on `@MainActor` via `Task`, and the
/// `isProcessing` guard defers it behind any in-progress action, so reentrancy is always safe —
/// effects never interleave with, or nest inside, an in-progress dispatch.
///
/// - Note: `@unchecked Sendable` is used because the mutable stored properties (`state`,
///   `effects`, etc.) are only accessed on `@MainActor`, but Swift cannot statically prove
///   this for a `final class` without `nonisolated(unsafe)` annotations on each property.
@MainActor
public final class Store<Action: Sendable, State: Sendable, Environment: Sendable>: StoreType, @unchecked Sendable {
    // MARK: - State

    /// The current state. Updated atomically in phase 2 of every dispatch cycle.
    public private(set) var state: State

    // MARK: - Core

    private let behavior: Behavior<Action, State, Environment>
    private let environment: Environment

    // MARK: - Registries

    /// All effects — both named (user-provided id) and anonymous (UUID key drawn from ``idGen``).
    /// UUID is Hashable & Sendable, so `AnyHashableSendable(idGen(&rng))` fits naturally
    /// alongside named keys. Each `SubscriptionToken` cancels its effect when released, so
    /// removing/replacing an entry — or deallocating the Store, which releases this whole
    /// dictionary — cancels the corresponding in-flight work automatically (no `deinit` needed).
    private var effects: [AnyHashableSendable: SubscriptionToken] = [:]

    /// Last-fire instants for `.throttle` keys (measured on the injected ``clock``), each paired
    /// with the interval that produced it so expired entries can be pruned — keeps the dictionary
    /// bounded under unbounded distinct keys.
    private var throttleTimestamps: [AnyHashableSendable: (last: AnyClock<Swift.Duration>.Instant, interval: Duration)] = [:]

    /// Both observer closures are stored together under one key so a single token cancels both.
    /// Keys come from ``nextObserverKey`` — a monotonic counter; these keys are internal and never
    /// surfaced, so no `UUID`/RNG is needed (a wrapping `UInt64` cannot realistically collide).
    private var stateObservers: [UInt64: (willChange: @MainActor @Sendable () -> Void,
                                          didChange: @MainActor @Sendable () -> Void)] = [:]
    private var nextObserverKey: UInt64 = 0

    // MARK: - Injected co-effects

    /// Clock used for all ``EffectScheduling`` timing (debounce sleep, throttle window). Erased to
    /// `AnyClock` so the Store carries no clock generic; injected at `init` (defaults to
    /// `ContinuousClock`, swappable for a `TestClock`/`ImmediateClock` of the same `Duration`).
    private let clock: AnyClock<Swift.Duration>

    /// Source of randomness for anonymous effect ids, threaded through ``idGen``. A seeded generator
    /// yields reproducible ids; defaults to the system RNG. Only mutated on `@MainActor`.
    private var rng: AnyRandomNumberGenerator

    /// Pure recipe turning ``rng`` into anonymous effect-registry ids — the `Gen`-based replacement
    /// for `UUID()`.
    private let idGen = Gen<UUID>.uuid()

    // MARK: - Dispatch serialization
    //
    // `queue` + `isProcessing` serialize the three-phase pipeline so it never runs nested.
    // Both are MainActor-isolated (no lock needed): the only off-actor caller is an effect's
    // `send`, which hops onto the main actor via `Task` before touching either.
    //
    // The rule: a synchronous `dispatch` runs its action — and any further actions dispatched
    // synchronously while it runs (e.g. a `didChange` observer that re-dispatches) — within the
    // current run loop turn, draining the queue in FIFO order without re-entering `runPhases`.
    // Effect-produced actions arrive through `makeSend`'s `Task` hop, so they are always
    // processed on a later turn.

    /// Actions awaiting processing. Drained in FIFO order by the active `process` loop.
    private var queue: [DispatchedAction<Action>] = []

    /// `true` while the `process` drain loop is running. Guards against re-entrant nesting.
    private var isProcessing = false

    // MARK: - Init

    /// Creates a `Store` with a pre-composed ``Behavior`` and an environment, driving
    /// ``EffectScheduling`` timing with a live `ContinuousClock`.
    ///
    /// Use this when you have already assembled your feature behaviors into a single
    /// `Behavior` using ``Behavior/combine(_:_:)`` or the `Monoid` fold:
    ///
    /// ```swift
    /// let store = Store(
    ///     initial: AppState.initial,
    ///     behavior: appBehavior,
    ///     environment: AppEnvironment.live
    /// )
    /// ```
    ///
    /// To drive scheduling with a `TestClock`/`ImmediateClock` — or to read the clock from the
    /// environment — use ``init(initial:behavior:environment:clock:rng:)``.
    ///
    /// - Parameters:
    ///   - state: The initial state value. The store takes exclusive ownership.
    ///   - behavior: The single ``Behavior`` that handles all dispatched actions.
    ///   - environment: The environment injected into ``Effect`` readers in phase 3.
    ///   - rng: Extracts the randomness source for anonymous effect ids from the environment.
    ///     Defaults to the system RNG; inject a seeded `SplitMix64` for reproducible ids.
    public convenience init(
        initial state: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment,
        rng: (Environment) -> AnyRandomNumberGenerator = { _ in AnyRandomNumberGenerator(SystemRandomNumberGenerator()) }
    ) {
        self.init(initial: state, behavior: behavior, environment: environment, clock: { _ in ContinuousClock() }, rng: rng)
    }

    /// Creates a `Store` extracting the scheduling clock — and optionally the RNG — from the
    /// environment.
    ///
    /// The concrete clock `C` is inferred at the call site and erased to `AnyClock` at
    /// construction, so `Store` carries no clock generic. Pass a `TestClock`/`ImmediateClock`
    /// for deterministic ``EffectScheduling`` in tests.
    ///
    /// - Parameters:
    ///   - state: The initial state value. The store takes exclusive ownership.
    ///   - behavior: The single ``Behavior`` that handles all dispatched actions.
    ///   - environment: The environment injected into ``Effect`` readers in phase 3.
    ///   - clock: Extracts the clock driving ``EffectScheduling`` timing from the environment.
    ///     Must have `Duration == Swift.Duration` (`ContinuousClock`, `TestClock`, `ImmediateClock`).
    ///   - rng: Extracts the randomness source for anonymous effect ids from the environment.
    ///     Defaults to the system RNG; inject a seeded `SplitMix64` for reproducible ids.
    public init<C: Clock>(
        initial state: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment,
        clock: (Environment) -> C,
        rng: (Environment) -> AnyRandomNumberGenerator = { _ in AnyRandomNumberGenerator(SystemRandomNumberGenerator()) }
    ) where C: Sendable, C.Duration == Swift.Duration {
        self.state = state
        self.behavior = behavior
        self.environment = environment
        self.clock = clock(environment).eraseToAnyClock()
        self.rng = rng(environment)
    }

    /// Creates a `Store` with a ``Reducer`` only (no side effects, `Environment == Void`).
    ///
    /// Convenient for pure state machines — counters, toggles, forms — that never need to
    /// perform async work:
    ///
    /// ```swift
    /// let store = Store(initial: 0, reducer: counterReducer)
    /// store.dispatch(.increment)
    /// store.dispatch(.increment)
    /// // store.state == 2
    /// ```
    ///
    /// - Parameters:
    ///   - state: The initial state value.
    ///   - reducer: The ``Reducer`` applied to every dispatched action.
    public convenience init(
        initial state: State,
        reducer: Reducer<Action, State>
    ) where Environment == Void {
        self.init(initial: state, behavior: reducer.asBehavior(), environment: ())
    }

    /// Creates a `Store` from a ``Behavior`` when the environment is `Void`.
    ///
    /// Saves the `environment: ()` boilerplate for behaviors that need no dependencies:
    ///
    /// ```swift
    /// let store = Store(initial: AppState.initial, behavior: appBehavior)
    /// ```
    ///
    /// - Parameters:
    ///   - state: The initial state value.
    ///   - behavior: The single ``Behavior`` that handles all dispatched actions.
    public convenience init(
        initial state: State,
        behavior: Behavior<Action, State, Environment>
    ) where Environment == Void {
        self.init(initial: state, behavior: behavior, environment: ())
    }

    /// Creates a `Store` by composing a ``Reducer`` and a ``Middleware`` internally.
    ///
    /// Equivalent to calling `Behavior(reducer:middleware:)` then using the primary init.
    /// The reducer handles mutations (phase 2) and the middleware handles effects (phase 3).
    ///
    /// ```swift
    /// let store = Store(
    ///     initial: AppState.initial,
    ///     reducer: appReducer,
    ///     middleware: appMiddleware,
    ///     environment: AppEnvironment.live
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - state: The initial state value.
    ///   - reducer: The ``Reducer`` applied to every dispatched action.
    ///   - middleware: The ``Middleware`` producing effects in response to actions.
    ///   - environment: The environment injected into ``Effect`` readers in phase 3.
    public convenience init(
        initial state: State,
        reducer: Reducer<Action, State>,
        middleware: Middleware<Action, State, Environment>,
        environment: Environment
    ) {
        self.init(
            initial: state,
            behavior: Behavior(reducer: reducer, middleware: middleware),
            environment: environment
        )
    }

    // MARK: - StoreType

    /// Dispatches an action, running it through the three-phase pipeline on `@MainActor`.
    ///
    /// The action is wrapped in a ``DispatchedAction`` carrying the explicit `source` provenance
    /// before entering the pipeline. Use the convenience overload ``dispatch(_:file:function:line:)``
    /// to capture the call site automatically.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - source: The call-site origin for logging and tracing.
    public func dispatch(_ action: Action, source: ActionSource) {
        process(DispatchedAction(action, dispatcher: source))
    }

    /// Registers callbacks for both sides of each state mutation.
    ///
    /// - `willChange` fires before the mutation — `state` still holds the old value.
    /// - `didChange` fires after the mutation — `state` holds the new value.
    ///
    /// The token is released on cancel via a `Task { @MainActor }` hop, keeping deregistration
    /// safe regardless of which thread calls ``SubscriptionToken/cancel()``.
    ///
    /// - Parameters:
    ///   - willChange: Called on `@MainActor` before each mutation.
    ///   - didChange: Called on `@MainActor` after each mutation.
    /// - Returns: A ``SubscriptionToken`` that cancels both callbacks when cancelled.
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        let id = nextObserverKey
        nextObserverKey &+= 1
        stateObservers[id] = (willChange: willChange, didChange: didChange)
        return SubscriptionToken { [weak self] in
            Task { @MainActor [weak self] in self?.stateObservers.removeValue(forKey: id) }
        }
    }

    // MARK: - Dispatch loop

    /// Enqueues `dispatched` and drains the queue in FIFO order, unless a drain is already
    /// running — in which case the active loop will pick it up after the current action.
    ///
    /// This is the single entry point for every action, whether it comes from a synchronous
    /// `dispatch` call or (via `makeSend`'s `Task` hop) from an effect. The `isProcessing`
    /// guard guarantees the three-phase pipeline in `runPhases` never runs nested.
    private func process(_ dispatched: DispatchedAction<Action>) {
        queue.append(dispatched)
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        var drained = 0
        while !queue.isEmpty {
            drained += 1
            if drained > StoreHooks.reentranceThreshold {
                let next = queue.first
                StoreHooks.onReentranceDetected(StoreReentranceInfo(
                    drainedCount: drained,
                    threshold: StoreHooks.reentranceThreshold,
                    source: next?.dispatcher,
                    actionDescription: next.map { String(describing: $0.action) }
                ))
                queue.removeAll()   // drop the runaway so the app can't hang
                break
            }
            runPhases(queue.removeFirst())
        }
    }

    private func runPhases(_ dispatched: DispatchedAction<Action>) {
        let preCtx = PreReducerContext<State>(
            source: dispatched.dispatcher,
            getter: { [weak self] in self?.state }
        )

        // Phase 1 — pre-mutation: collect ReducerOutcome + Reader from the behavior
        let consequence = behavior.handle(dispatched.action, preCtx)

        // Phase 2 — zero-copy mutation, bracketed by observer notifications. A provably no-op
        // action (`.unchanged` — pure routing, effect-only, `.doNothing`) fires no notifications,
        // so ObservableObject/@Observable consumers never re-render on actions that can't change
        // state. `willChange` still precedes the mutation (ObservableObject.objectWillChange
        // requirement) and `didChange` follows it.
        switch consequence.mutation {
        case .unchanged:
            break
        case .mutation(let mutation):
            stateObservers.values.forEach { $0.willChange() }
            mutation.runEndoMut(&state)
            stateObservers.values.forEach { $0.didChange() }
        }

        // Phase 4 — schedule effects (postCtx.stateGetter now reflects post-mutation state)
        let postCtx = PostReducerContext<State, Environment>(
            environment: environment,
            getter: { [weak self] in self?.state }
        )
        let effect = consequence.effect(postCtx)
        effect.components.forEach { schedule($0) }
    }

    // MARK: - Effect scheduling

    private func schedule(_ component: Effect<Action>.Component) {
        switch component.scheduling {
        case .immediately:
            let key = AnyHashableSendable(idGen(&rng))
            let token = component.subscribe(makeSend()) { [weak self] in
                Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
            }
            effects[key] = token

        case .replacing(let key):
            effects[key]?.cancel()
            let token = component.subscribe(makeSend()) { [weak self] in
                Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
            }
            effects[key] = token

        case .cancelInFlight(let key):
            effects[key]?.cancel()
            effects.removeValue(forKey: key)

        case let .debounce(key, delay):
            effects[key]?.cancel()
            let send = makeSend()
            let clock = clock
            let task = Task { @MainActor [weak self] in
                // Clamp negative delays to zero so a past deadline resolves immediately.
                try await clock.sleep(for: max(.zero, delay))
                guard !Task.isCancelled, let self else { return }
                let token = component.subscribe(send) { [weak self] in
                    Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
                }
                self.effects[key] = token
            }
            effects[key] = SubscriptionToken { task.cancel() }

        case let .throttle(key, interval):
            let now = clock.now
            // Prune entries whose interval has elapsed so the dictionary stays bounded.
            throttleTimestamps = throttleTimestamps.filter { $0.value.last.duration(to: now) < $0.value.interval }
            if let entry = throttleTimestamps[key], entry.last.duration(to: now) < interval { return }
            throttleTimestamps[key] = (last: now, interval: interval)
            effects[key]?.cancel()
            let token = component.subscribe(makeSend()) { [weak self] in
                Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
            }
            effects[key] = token
        }
    }

    private func makeSend() -> @Sendable (DispatchedAction<Action>) -> Void {
        { [weak self] dispatched in
            Task { @MainActor [weak self] in self?.process(dispatched) }
        }
    }
}
