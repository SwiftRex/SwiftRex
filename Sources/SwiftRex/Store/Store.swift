import CoreFP
import DataStructure
import Foundation

// Swift 6.3+ stdlib declares AnyHashable: Sendable, but SourceKit lags behind the compiler.
// Repeating it here keeps IDE diagnostics clean; the compiler ignores the duplicate.
extension AnyHashable: @retroactive @unchecked Sendable {}

/// The sole owner of mutable `State`. All mutation and dispatch happen on `@MainActor`.
///
/// **Dispatch — three phases per action:**
/// ```
/// 1. behavior.handle(action, stateAccess)    pre-mutation reads, all Behaviors
/// 2. stateObservers.willChange fired         ObservableObject fires objectWillChange here
///    consequence.mutation.runEndoMut(&state)  zero-copy inout, refcount = 1
/// 3. stateObservers.didChange fired          @Observable / push-based observers
///    consequence.effect scheduled            per-component EffectScheduling
/// ```
@MainActor
public final class Store<Action: Sendable, State: Sendable, Environment: Sendable>: StoreType, @unchecked Sendable {

    // MARK: - State

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
                                        didChange:  @MainActor @Sendable () -> Void)] = [:]

    // MARK: - Init

    public init(
        initial state: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment
    ) {
        self.state = state
        self.behavior = behavior
        self.environment = environment
    }

    public convenience init(
        initial state: State,
        reducer: Reducer<Action, State>
    ) where Environment == Void {
        self.init(initial: state, behavior: reducer.asBehavior(), environment: ())
    }

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

    public func dispatch(_ action: Action, source: ActionSource) {
        handle(DispatchedAction(action, dispatcher: source))
    }

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

        // Phase 1 — pre-mutation
        let consequence = behavior.handle(dispatched, stateAccess)

        // Notify will-change BEFORE mutation (ObservableObject objectWillChange requirement)
        stateObservers.values.forEach { $0.willChange() }

        // Phase 2 — zero-copy mutation
        consequence.mutation.runEndoMut(&state)

        // Phase 3 — post-mutation
        stateObservers.values.forEach { $0.didChange() }

        // Phase 4 — schedule effects (stateAccess now reads post-mutation state)
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

        case .debounce(let key, let delay):
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

        case .throttle(let key, let interval):
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
