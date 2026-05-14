import CoreFP
import SwiftRex
import Testing

/// A controllable, synchronous store for testing ``Behavior`` values.
///
/// `TestStore` runs the behavior's dispatch pipeline deterministically:
/// - ``send(_:sourceLocation:assert:)`` applies phases 1 and 2 immediately (handle → mutate),
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
/// ``send(_:sourceLocation:assert:)`` requires a trailing closure that describes the expected
/// state change. The closure receives an `inout` copy of the state before the action and you
/// mutate it to reflect what you expect after the action runs. Pass `{ _ in }` when no state
/// change is expected.
///
/// ``receive`` closures also describe expected state. For actions with an associated value the
/// closure receives both the extracted value and `inout State`, so you can use the actual value
/// from the action when specifying what the state should become:
///
/// ```swift
/// // send: describe what state should look like after the action
/// store.send(.setPage(3)) { $0.currentPage = 3 }
///
/// // receive with associated value: value comes from the action itself
/// store.receive(AppAction.prism.didLoad) { items, state in
///     state.isLoading = false
///     state.items = items     // items is the [Item] extracted by the prism
/// }
///
/// // receive without associated value (Void prism)
/// store.receive(AppAction.prism.didReset) { $0 = .initial }
/// ```
///
/// ## Action matching via Prism
///
/// `receive` validates the received action by applying a ``Prism``. If the prism's `preview`
/// returns `nil` (action is a different case), a failure is recorded but the action is still
/// dispatched so subsequent assertions remain meaningful.
///
/// This design avoids requiring `Action: Equatable` — actions are often algebraic types whose
/// associated values are not `Equatable`, and requiring conformance just for testing is
/// unreasonably restrictive.
///
/// ## Exhaustive mode (default)
///
/// In exhaustive mode (`exhaustive: true`) the store enforces a strict discipline:
///
/// - Calling ``send(_:sourceLocation:assert:)`` while ``receivedActions`` is non-empty records a
///   test failure — process all received actions first.
/// - When the `TestStore` is deallocated (end of the test function), any remaining
///   ``pendingEffects`` or ``receivedActions`` also record failures.
///
/// Pass `exhaustive: false` to opt out of ordering enforcement and end-of-test checks.
@MainActor
public final class TestStore<Action: Sendable, State: Sendable & Equatable, Environment: Sendable> {
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
    private let environment: Environment

    // Mirrored counts for deinit — Swift 6 deinit is nonisolated and cannot read @MainActor
    // storage. These are written on @MainActor and only read in deinit.
    nonisolated(unsafe) private var _pendingCount: Int = 0
    nonisolated(unsafe) private var _receivedCount: Int = 0
    nonisolated(unsafe) private let _exhaustive: Bool

    // MARK: - Init

    /// Creates a `TestStore` with a ``Behavior`` and an environment.
    ///
    /// - Parameters:
    ///   - initial: The starting state.
    ///   - behavior: The behavior under test.
    ///   - environment: The environment injected into effects via `Reader`.
    ///   - exhaustive: When `true` (default), enforces ordering and end-of-test checks.
    ///     Pass `false` to disable all checks.
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

    // MARK: - Test API

    /// Dispatches `action` through the behavior and validates the resulting state.
    ///
    /// The `assert` closure receives an `inout` copy of the state **before** dispatch. Mutate it
    /// to produce the expected post-action state; a mismatch records a test failure.
    ///
    /// In exhaustive mode, a failure is also recorded when ``receivedActions`` is non-empty —
    /// process them with `receive` first.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action state to produce the expected post-action state.
    ///     Pass `{ _ in }` when no state change is expected.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func send(
        _ action: Action,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedStateChange: (inout State) -> Void
    ) -> Self {
        if _exhaustive && _receivedCount > 0 {
            Issue.record(
                """
                send(\(action)) called with \(_receivedCount) unprocessed received action(s). \
                Call receive() for each before dispatching again.
                """,
                sourceLocation: sourceLocation
            )
        }
        let before = state
        dispatch(DispatchedAction(action))
        assertState(before: before, after: state, label: "send(\(action))", sourceLocation: sourceLocation, expectedChange: expectedStateChange)
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
    ///   - assert: Receives the value extracted by `prism` and an `inout` copy of the pre-action
    ///     state; mutate the state to produce the expected post-action state.
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
            dispatch(DispatchedAction(action))
            return action
        }
        let before = state
        dispatch(DispatchedAction(action))
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

    // MARK: - Private

    private func dispatch(_ dispatched: DispatchedAction<Action>) {
        let stateAccess = StateAccess { [weak self] in self?.state }
        let consequence = behavior.handle(dispatched, stateAccess)
        consequence.mutation.runEndoMut(&state)
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
    /// store.send(.increment) { $0.count += 1 }
    /// ```
    public convenience init(
        initial: State,
        reducer: Reducer<Action, State>,
        exhaustive: Bool = true
    ) {
        self.init(initial: initial, behavior: reducer.asBehavior(), environment: (), exhaustive: exhaustive)
    }
}
