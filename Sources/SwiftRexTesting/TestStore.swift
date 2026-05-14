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
/// - ``receive(sourceLocation:assert:)`` dequeues the next received action, dispatches it through
///   the behavior, validates the resulting state, and returns the action for assertion.
///
/// ## State assertions
///
/// Both ``send(_:sourceLocation:assert:)`` and ``receive(sourceLocation:assert:)`` require a
/// trailing closure that describes the **expected** state change. The closure receives an `inout`
/// copy of the state before the action and you mutate it to what you expect:
///
/// ```swift
/// store.send(.increment) { $0.count += 1 }
/// store.send(.setUsername("Alice")) { $0.profile.username = "Alice" }
/// ```
///
/// If the actual state after the action does not equal the expected state produced by the closure,
/// a test failure is recorded. Pass `{ _ in }` when an action is expected to produce no state
/// change.
///
/// ## Exhaustive mode (default)
///
/// In exhaustive mode (`exhaustive: true`) the store enforces a strict discipline:
///
/// - Calling ``send(_:sourceLocation:assert:)`` while ``receivedActions`` is non-empty records a
///   test failure — process all received actions with ``receive(sourceLocation:assert:)`` before
///   dispatching again.
/// - When the `TestStore` is deallocated (end of the test function), any remaining
///   ``pendingEffects`` or ``receivedActions`` also record failures.
///
/// Pass `exhaustive: false` to opt out of ordering enforcement and end-of-test checks.
///
/// ```swift
/// @Test func effectDispatches() async {
///     let store = TestStore(initial: AppState(), behavior: appBehavior, environment: testEnv)
///
///     store.send(.load) { $0.isLoading = true }
///
///     await store.runEffects()
///     let action = store.receive { $0.isLoading = false; $0.data = mockData }
///     #expect(action == .didLoad(mockData))
/// }
/// ```
@MainActor
public final class TestStore<Action: Sendable & Equatable, State: Sendable & Equatable, Environment: Sendable> {
    /// The current state after all dispatched and received actions have been processed.
    public private(set) var state: State

    /// Effects captured from dispatched or received actions that have not yet been run.
    ///
    /// Each ``send(_:sourceLocation:assert:)`` or ``receive(sourceLocation:assert:)`` call
    /// appends any produced ``Effect`` here. Call ``runEffects()`` to execute them and collect
    /// their output.
    public private(set) var pendingEffects: [Effect<Action>] = []

    /// Actions produced by effects that have not yet been dispatched through the behavior.
    ///
    /// Call ``receive(sourceLocation:assert:)`` for each entry to propagate it through the
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
    ///   - exhaustive: When `true` (default), enforces ordering: all received actions must be
    ///     processed before dispatching again, and all pending work must be exhausted by the time
    ///     the store is released. Pass `false` to disable all checks.
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
    /// The `assert` closure receives an `inout` copy of the state **before** the action was
    /// dispatched. Mutate it to produce the **expected** post-action state. If the actual state
    /// does not equal the expected state, a test failure is recorded.
    ///
    /// In exhaustive mode, a failure is also recorded when ``receivedActions`` is non-empty —
    /// call ``receive(sourceLocation:assert:)`` to process all received actions first.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: A closure that mutates the pre-action state to produce the expected
    ///     post-action state. Pass `{ _ in }` when no state change is expected.
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
    /// After this call, ``pendingEffects`` is empty. Use ``receive(sourceLocation:assert:)`` to
    /// process each collected action through the behavior.
    ///
    /// Effects are run in order; components within each effect run sequentially. Each component
    /// is driven to completion before the next one starts.
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

    /// Dequeues and dispatches the next action in ``receivedActions`` through the behavior,
    /// then validates the resulting state.
    ///
    /// The `assert` closure receives an `inout` copy of the state **before** the received action
    /// was dispatched. Mutate it to produce the **expected** post-action state. If the actual
    /// state does not equal the expected state, a test failure is recorded.
    ///
    /// A failure is also recorded when ``receivedActions`` is empty — call ``runEffects()`` first
    /// if you expect effect output.
    ///
    /// - Parameters:
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: A closure that mutates the pre-action state to produce the expected
    ///     post-action state. Pass `{ _ in }` when no state change is expected.
    /// - Returns: The action that was processed, or `nil` if ``receivedActions`` was empty.
    @discardableResult
    public func receive(
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedStateChange: (inout State) -> Void
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
        let before = state
        dispatch(DispatchedAction(action))
        assertState(before: before, after: state, label: "receive(\(action))", sourceLocation: sourceLocation, expectedChange: expectedStateChange)
        return action
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
