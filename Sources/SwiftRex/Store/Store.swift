import CoreFP
import DataStructure
import Foundation

// Swift 6.3+ stdlib declares AnyHashable: Sendable, but SourceKit lags behind the compiler.
// Repeating it here keeps IDE diagnostics clean; the compiler ignores the duplicate.
extension AnyHashable: @retroactive @unchecked Sendable {}

/// The sole owner of mutable `State` and the central coordinator of the three-phase dispatch pipeline.
///
/// Create one `Store` per application and pass it — or narrowed ``StoreProjection`` values — to
/// your features. The ``Store`` is `@MainActor`, so all state reads, mutations, and observer
/// notifications happen on the main thread without any manual actor-hopping.
///
/// ## Three-phase dispatch
///
/// Every call to ``dispatch(_:source:)`` runs through four steps:
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
/// Each ``Effect/Component`` is tracked in `effects: [AnyHashable: SubscriptionToken]`.
/// Anonymous (`.immediately`) components use a `UUID` key that is removed on `complete`.
/// Named components (`.replacing`, `.debounce`, `.throttle`) use the caller-supplied id.
///
/// Dispatching from inside an effect re-enters the pipeline on `@MainActor` via `Task`, so
/// reentrancy is always safe — effects never interleave with an in-progress dispatch.
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

    /// All effects — both named (user-provided AnyHashable key) and anonymous (UUID key).
    /// UUID is Hashable, so AnyHashable(UUID()) fits naturally alongside named keys.
    private var effects: [AnyHashable: SubscriptionToken] = [:]
    private var throttleTimestamps: [AnyHashable: Date]   = [:]

    /// Both observer closures are stored together under one UUID so a single token cancels both.
    private var stateObservers: [UUID: (willChange: @MainActor @Sendable () -> Void,
                                        didChange: @MainActor @Sendable () -> Void)] = [:]

    // MARK: - Init

    /// Creates a `Store` with a pre-composed ``Behavior`` and an environment.
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
    /// - Parameters:
    ///   - state: The initial state value. The store takes exclusive ownership.
    ///   - behavior: The single ``Behavior`` that handles all dispatched actions.
    ///   - environment: The environment injected into ``Effect`` readers in phase 3.
    public init(
        initial state: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment
    ) {
        self.state = state
        self.behavior = behavior
        self.environment = environment
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
        handle(DispatchedAction(action, dispatcher: source))
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
    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        let id = UUID()
        stateObservers[id] = (willChange: willChange, didChange: didChange)
        return SubscriptionToken { [weak self] in
            Task { @MainActor [weak self] in self?.stateObservers.removeValue(forKey: id) }
        }
    }

    // MARK: - Dispatch loop

    private func handle(_ dispatched: DispatchedAction<Action>) {
        let stateAccess = StateAccess { [weak self] in self?.state }

        // Phase 1 — pre-mutation: collect EndoMut + Reader from the behavior
        let consequence = behavior.handle(dispatched, stateAccess)

        // Notify will-change BEFORE mutation (ObservableObject.objectWillChange requirement)
        stateObservers.values.forEach { $0.willChange() }

        // Phase 2 — zero-copy mutation: apply EndoMut directly to stored state
        consequence.mutation.runEndoMut(&state)

        // Phase 3 — post-mutation: notify observers and run Reader
        stateObservers.values.forEach { $0.didChange() }

        // Phase 4 — schedule effects (stateAccess now reflects post-mutation state)
        let effect = consequence.effect.runReader(environment)
        effect.components.forEach { schedule($0) }
    }

    // MARK: - Effect scheduling

    private func schedule(_ component: Effect<Action>.Component) {
        switch component.scheduling {
        case .immediately:
            let key = AnyHashable(UUID())
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
            let task = Task { @MainActor [weak self] in
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                let token = component.subscribe(send) { [weak self] in
                    Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
                }
                self.effects[key] = token
            }
            effects[key] = SubscriptionToken { task.cancel() }

        case let .throttle(key, interval):
            let now = Date()
            if let last = throttleTimestamps[key], now.timeIntervalSince(last) < interval { return }
            throttleTimestamps[key] = now
            effects[key]?.cancel()
            let token = component.subscribe(makeSend()) { [weak self] in
                Task { @MainActor [weak self] in self?.effects.removeValue(forKey: key) }
            }
            effects[key] = token
        }
    }

    private func makeSend() -> @Sendable (DispatchedAction<Action>) -> Void {
        { [weak self] dispatched in
            Task { @MainActor [weak self] in self?.handle(dispatched) }
        }
    }
}
