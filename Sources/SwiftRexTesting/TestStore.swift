import CoreFP
import Foundation
import SwiftRex
import Testing

/// A controllable, synchronous store for testing ``Behavior`` values at the **domain**
/// layer (assert on `State`, match on `Action`).
///
/// `TestStore` is the lower-level primitive. For a higher-level test harness that
/// assert at the **view-state** layer and gives you access to the rendered view for
/// snapshot testing, use ``TestFeature`` from the same module.
///
/// `TestStore` drives the dispatch pipeline deterministically:
/// - ``dispatch(_:sourceLocation:assert:)`` applies phases 1 and 2 immediately (handle → mutate),
///   validates the resulting state against an assertion closure, and captures any produced
///   ``Effect`` into ``pendingEffects`` without starting it.
/// - ``runEffects()`` drives all pending effects and collects their output actions into
///   ``receivedActions``.
/// - ``receive(_:sourceLocation:assert:)-9ofio`` (with associated value) or
///   ``receive(_:sourceLocation:assert:)-6yjj4`` (without associated value) validates that
///   the next received action matches a ``Prism``, dispatches it through the behavior, and
///   validates the resulting state.
///
/// ## State assertions
///
/// Both ``dispatch(_:sourceLocation:assert:)`` and ``receive`` require a trailing closure that
/// describes the expected state change. The closure receives an `inout` copy of the state
/// *before* the action and you mutate it to reflect what you expect *after* the action runs.
/// Pass `{ _ in }` when no state change is expected.
///
/// For `receive`, actions with an associated value give you that value in the closure so you
/// can use the actual payload from the action rather than duplicating it:
///
/// ```swift
/// // dispatch: describe the expected state change
/// store.dispatch(.setPage(3)) { $0.currentPage = 3 }
///
/// // receive with associated value — value is extracted from the action by the prism
/// store.receive(AppAction.prism.didLoad) { items, state in
///     state.isLoading = false
///     state.items = items
/// }
///
/// // receive without associated value (Void prism)
/// store.receive(AppAction.prism.didReset) { $0 = .initial }
/// ```
///
/// ## Action matching via Prism
///
/// `receive` validates the received action by applying a ``Prism``. If `preview` returns `nil`
/// (different action case), a failure is recorded but the action is still dispatched so
/// subsequent assertions remain meaningful.
///
/// This avoids requiring `Action: Equatable` — actions are often algebraic types whose
/// associated values are not `Equatable`, and requiring conformance just for testing is
/// unreasonably restrictive.
///
/// ## Exhaustive mode (default)
///
/// When `exhaustive: true` (the default), the store enforces two checks:
///
/// 1. **Ordering** — calling ``dispatch(_:sourceLocation:assert:)`` while ``receivedActions``
///    is non-empty records a failure. You must process all received actions with `receive`
///    before dispatching again.
/// 2. **End-of-test** — when the `TestStore` is deallocated, any remaining ``pendingEffects``
///    or ``receivedActions`` record failures. Every effect and every action the behavior
///    produced must be accounted for.
///
/// Pass `exhaustive: false` to disable **both** checks — neither the ordering check on
/// dispatch nor the end-of-test check at dealloc will fire.
///
/// ## StoreType conformance
///
/// `TestStore` conforms to ``StoreType`` so it can be used as a backing store for
/// ``StoreProjection``, enabling ``TestFeature`` to wire a live ``ViewModel`` directly
/// to the test store and capture ``view`` for snapshot testing.
@MainActor
public final class TestStore<Action: Sendable, State: Sendable & Equatable, Environment: Sendable>: StoreType, @unchecked Sendable {
    /// The current state after all dispatched and received actions have been processed.
    public private(set) var state: State

    /// Effects captured from dispatched or received actions that have not yet been run.
    ///
    /// Call ``runEffects()`` to execute them and collect their output into ``receivedActions``.
    public private(set) var pendingEffects: [Effect<Action>] = []

    /// Actions produced by effects that have not yet been dispatched through the behavior.
    ///
    /// Call ``receive(_:sourceLocation:assert:)-9ofio`` or
    /// ``receive(_:sourceLocation:assert:)-6yjj4`` for each entry to propagate it through the
    /// behavior, updating ``state`` and potentially adding new entries to ``pendingEffects``.
    public private(set) var receivedActions: [Action] = []

    private let behavior: Behavior<Action, State, Environment>
    /// The injected environment. Publicly mutable so test code can swap or tweak it
    /// between effect runs — see ``FeatureStep/runEffects(before:after:)``.
    ///
    /// Note: pending effects are reader-provided at dispatch time; mutating `environment`
    /// affects future dispatches and any closure that captures mutable state, but does
    /// not retroactively rebind already-pending effects.
    public var environment: Environment

    /// Registered will/didChange callbacks — keyed by UUID so a single token cancels both.
    private var stateObservers: [UUID: (willChange: @MainActor @Sendable () -> Void,
                                        didChange: @MainActor @Sendable () -> Void)] = [:]

    // Mirrored counts for deinit — Swift 6 deinit is nonisolated and cannot read @MainActor
    // storage. These are written on @MainActor and only read in deinit.
    nonisolated(unsafe) private var _pendingCount: Int = 0
    nonisolated(unsafe) private var _receivedCount: Int = 0
    // Bool is Sendable; nonisolated(unsafe) is only needed for the var counts above.
    private let _exhaustive: Bool

    /// When `true`, ``dispatch(_:source:)`` is a no-op — view-driven dispatches are dropped
    /// while the store is "frozen". Test-driven dispatch (``TestFeature/dispatch(_:)``) and
    /// ``receive`` keep working.
    ///
    /// Toggle via ``TestFeature/ignoringActions(_:)``.
    public var isIgnoringActions: Bool = false

    // MARK: - Init

    /// Creates a `TestStore` with a ``Behavior`` and an environment.
    ///
    /// - Parameters:
    ///   - initial: The starting state.
    ///   - behavior: The behavior under test.
    ///   - environment: The environment injected into effects via `Reader`.
    ///   - exhaustive: When `true` (default), enforces both the ordering check (no dispatch
    ///     while received actions are pending) and the end-of-test check (no leftover effects
    ///     or actions at dealloc). Pass `false` to disable both checks.
    public init(
        initial: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment,
        exhaustive: Bool = true
    ) {
        self.state = initial
        self.behavior = behavior
        self.environment = environment
        self._exhaustive = exhaustive
    }

    // MARK: - Deinit check

    deinit {
        guard _exhaustive else { return }
        if _pendingCount > 0 {
            Issue.record(
                "\(_pendingCount) pending effect(s) were not run before the TestStore was released — call runEffects() to drain them"
            )
        }
        if _receivedCount > 0 {
            Issue.record(
                "\(_receivedCount) received action(s) were not processed before the TestStore was released — call receive() for each"
            )
        }
    }

    // MARK: - StoreType

    /// Dispatches an action through the behavior without a test assertion.
    ///
    /// This satisfies the ``StoreType`` requirement and is used internally when a
    /// ``StoreProjection`` (e.g. inside a ``TestFeature`` ViewModel) forwards a dispatch.
    /// For test-driven dispatch with state assertions, use ``dispatch(_:sourceLocation:assert:)``.
    public func dispatch(_ action: Action, source: ActionSource) {
        guard !isIgnoringActions else { return }
        run(DispatchedAction(action, dispatcher: source))
    }

    /// Registers callbacks for both sides of each state mutation.
    ///
    /// Required by ``StoreType``; used by ``StoreProjection`` and ``ViewModel`` to observe
    /// state changes. In `TestStore`, callbacks fire **synchronously** inside each `run(_:)` call,
    /// so ``ViewModel``-tracked properties update immediately when ``dispatch(_:sourceLocation:assert:)``
    /// or ``receive`` runs — one ``TestFeature/flush()`` is enough for SwiftUI to pick up the change.
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

    // MARK: - Enqueue (used by TestFeature)

    /// Appends `action` directly to ``receivedActions`` without running it through the behavior.
    ///
    /// Used by ``TestFeature`` so that `dispatch(viewAction:)` makes the mapped domain action
    /// visible as the first entry in the received queue — keeping the whole dispatch → receive
    /// cycle symmetric and explicit.
    public func enqueue(_ action: Action) {
        receivedActions.append(action)
        _receivedCount = receivedActions.count
    }

    // MARK: - Test API

    /// Dispatches `action` through the behavior and validates the resulting state.
    ///
    /// The `assert` closure receives an `inout` copy of the state **before** dispatch. Mutate it
    /// to produce the expected post-action state; a mismatch records a test failure.
    ///
    /// In exhaustive mode, a failure is also recorded when ``receivedActions`` is non-empty —
    /// process them with `receive` first. In non-exhaustive mode this check is skipped.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action state to produce the expected post-action state.
    ///     Pass `{ _ in }` when no state change is expected.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func dispatch(
        _ action: Action,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedStateChange: (inout State) -> Void
    ) -> Self {
        if _exhaustive && _receivedCount > 0 {
            Issue.record(
                """
                dispatch(\(action)) called with \(_receivedCount) unprocessed received action(s). \
                Call receive() for each before dispatching again.
                """,
                sourceLocation: sourceLocation
            )
        }
        let before = state
        run(DispatchedAction(action))
        assertState(
            before: before,
            after: state,
            label: "dispatch(\(action))",
            sourceLocation: sourceLocation,
            expectedChange: expectedStateChange
        )
        return self
    }

    /// Executes all ``pendingEffects`` and appends their output actions to ``receivedActions``.
    ///
    /// Effects run in order; components within each effect run sequentially, each driven to
    /// completion before the next starts.
    public func runEffects() async {
        var toRun: [Effect<Action>] = []
        swap(&toRun, &pendingEffects)
        _pendingCount = 0
        for effect in toRun {
            for component in effect.components {
                let actions = await drain(component)
                receivedActions.append(contentsOf: actions)
            }
        }
        _receivedCount = receivedActions.count
    }

    /// Dequeues the next action from ``receivedActions``, validates it via `prism`, dispatches
    /// it through the behavior, and validates the resulting state.
    ///
    /// The `assert` closure receives both the **value extracted by the prism** and an `inout`
    /// copy of the state before dispatch — use the extracted value when specifying what the
    /// state should become:
    ///
    /// ```swift
    /// store.receive(AppAction.prism.didLoad) { items, state in
    ///     state.isLoading = false
    ///     state.items = items
    /// }
    /// ```
    ///
    /// If the prism does not match the dequeued action, an action-mismatch failure is recorded
    /// and the action is still dispatched so subsequent assertions remain meaningful.
    ///
    /// - Parameters:
    ///   - prism: A ``Prism`` whose `preview` must return non-nil for the expected action case.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Receives the value extracted by `prism` and an `inout` copy of the
    ///     pre-action state; mutate the state to produce the expected post-action state.
    @discardableResult
    public func receive<Value>(
        _ prism: Prism<Action, Value>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedStateChange: (Value, inout State) -> Void
    ) -> Action? {
        guard !receivedActions.isEmpty else {
            Issue.record(
                "receive() called but receivedActions is empty — call runEffects() first if you expect effect output",
                sourceLocation: sourceLocation
            )
            return nil
        }
        let action = receivedActions.removeFirst()
        _receivedCount = receivedActions.count
        guard let value = prism.preview(action) else {
            Issue.record(
                "Action case mismatch in receive() — prism did not match the dequeued action\nActual: \(action)",
                sourceLocation: sourceLocation
            )
            run(DispatchedAction(action))
            return action
        }
        let before = state
        run(DispatchedAction(action))
        var expected = before
        expectedStateChange(value, &expected)
        if state != expected {
            Issue.record(
                """
                State mismatch after receive(\(action))
                Expected: \(expected)
                  Actual: \(state)
                """,
                sourceLocation: sourceLocation
            )
        }
        return action
    }

    /// Dequeues the next action from ``receivedActions``, validates it via `prism` (no associated
    /// value), dispatches it through the behavior, and validates the resulting state.
    ///
    /// Use this overload for action cases that carry no associated value:
    ///
    /// ```swift
    /// store.receive(AppAction.prism.didReset) { $0 = .initial }
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A ``Prism<Action, Void>`` matching an action case with no associated value.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action state to produce the expected post-action state.
    ///     Pass `{ _ in }` when no state change is expected.
    @discardableResult
    public func receive(
        _ prism: Prism<Action, Void>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedStateChange: (inout State) -> Void
    ) -> Action? {
        receive(prism, sourceLocation: sourceLocation) { (_, state: inout State) in
            expectedStateChange(&state)
        }
    }

    // MARK: - Module-internal (used by TestFeature, which asserts on ViewState
    // and therefore must dispatch the domain action without TestStore second-guessing
    // it at the domain-State layer).

    @discardableResult
    func dequeueAndRun<Value>(
        _ prism: Prism<Action, Value>,
        sourceLocation: SourceLocation
    ) -> (action: Action, value: Value)? {
        guard !receivedActions.isEmpty else {
            Issue.record(
                "receive() called but receivedActions is empty — call runEffects() first if you expect effect output",
                sourceLocation: sourceLocation
            )
            return nil
        }
        let action = receivedActions.removeFirst()
        _receivedCount = receivedActions.count
        guard let value = prism.preview(action) else {
            Issue.record(
                "Action case mismatch in receive() — prism did not match the dequeued action\nActual: \(action)",
                sourceLocation: sourceLocation
            )
            run(DispatchedAction(action))
            return nil
        }
        run(DispatchedAction(action))
        return (action, value)
    }

    // MARK: - Private

    private func run(_ dispatched: DispatchedAction<Action>) {
        let stateAccess = StateAccess { [weak self] in self?.state }
        let consequence = behavior.handle(dispatched, stateAccess)
        stateObservers.values.forEach { $0.willChange() }
        consequence.mutation.runEndoMut(&state)
        stateObservers.values.forEach { $0.didChange() }
        let effect = consequence.effect.runReader(environment)
        if !effect.components.isEmpty {
            pendingEffects.append(effect)
        }
        _pendingCount = pendingEffects.count
    }

    private func assertState(
        before: State,
        after: State,
        label: String,
        sourceLocation: SourceLocation,
        expectedChange: (inout State) -> Void
    ) {
        var expected = before
        expectedChange(&expected)
        guard after != expected else { return }
        Issue.record(
            """
            State mismatch after \(label)
            Expected: \(expected)
              Actual: \(after)
            """,
            sourceLocation: sourceLocation
        )
    }

    private func drain(_ component: Effect<Action>.Component) async -> [Action] {
        let (stream, continuation) = AsyncStream.makeStream(of: Action.self)
        let token = component.subscribe(
            { dispatched in continuation.yield(dispatched.action) },
            { continuation.finish() }
        )
        var actions: [Action] = []
        for await action in stream { actions.append(action) }
        _ = token
        return actions
    }
}

// MARK: - Convenience initialisers

extension TestStore where Environment == Void {
    /// Creates a `TestStore` from a ``Behavior`` with `Void` environment.
    public convenience init(
        initial: State,
        behavior: Behavior<Action, State, Void>,
        exhaustive: Bool = true
    ) {
        self.init(initial: initial, behavior: behavior, environment: (), exhaustive: exhaustive)
    }

    /// Creates a `TestStore` from a pure ``Reducer`` (no side effects, `Environment == Void`).
    ///
    /// ```swift
    /// let store = TestStore(initial: CounterState(), reducer: counterReducer)
    /// store.dispatch(.increment) { $0.count += 1 }
    /// ```
    public convenience init(
        initial: State,
        reducer: Reducer<Action, State>,
        exhaustive: Bool = true
    ) {
        self.init(initial: initial, behavior: reducer.asBehavior(), environment: (), exhaustive: exhaustive)
    }
}
