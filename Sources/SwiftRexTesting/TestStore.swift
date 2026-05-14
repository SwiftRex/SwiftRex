import SwiftRex

/// A controllable, synchronous store for testing ``Behavior`` values.
///
/// `TestStore` runs the behavior's dispatch pipeline deterministically:
/// - ``send(_:)`` applies phases 1 and 2 immediately (handle → mutate) and captures any
///   produced ``Effect`` into ``pendingEffects`` without starting it.
/// - ``runEffects()`` drives all pending effects and collects their output actions into
///   ``receivedActions``.
/// - ``receive()`` dequeues the next received action, runs it through the behavior (updating
///   ``state`` and capturing new effects), and returns it for assertion.
///
/// ```swift
/// @Test func counterFlow() async {
///     let store = TestStore(initial: Counter(), reducer: counterReducer)
///     store.send(.increment)
///     #expect(store.state.count == 1)
/// }
///
/// @Test func effectDispatches() async {
///     let store = TestStore(initial: AppState(), behavior: appBehavior, environment: testEnv)
///     store.send(.load)
///     #expect(store.state.isLoading)
///     #expect(!store.pendingEffects.isEmpty)
///
///     await store.runEffects()
///     let action = store.receive()
///     #expect(action == .didLoad(mockData))
///     #expect(store.state.data == mockData)
/// }
/// ```
///
/// Because `TestStore` is `@MainActor`, all methods are safe to call from `@MainActor`-isolated
/// test functions — which is the default for Swift Testing `@Test` functions that call `@MainActor`
/// APIs.
@MainActor
public final class TestStore<Action: Sendable & Equatable, State: Sendable & Equatable, Environment: Sendable> {
    /// The current state after all dispatched and received actions have been processed.
    public private(set) var state: State

    /// Effects captured from dispatched or received actions that have not yet been run.
    ///
    /// Each ``send(_:)`` or ``receive()`` call appends any produced ``Effect`` here.
    /// Call ``runEffects()`` to execute them and collect their output actions.
    public private(set) var pendingEffects: [Effect<Action>] = []

    /// Actions produced by effects that have not yet been processed through the behavior.
    ///
    /// Call ``receive()`` for each entry to propagate it through the behavior, updating
    /// ``state`` and potentially adding new entries to ``pendingEffects``.
    public private(set) var receivedActions: [Action] = []

    private let behavior: Behavior<Action, State, Environment>
    private let environment: Environment

    /// Creates a `TestStore` with a ``Behavior`` and an environment.
    ///
    /// - Parameters:
    ///   - initial: The starting state.
    ///   - behavior: The behavior under test.
    ///   - environment: The environment injected into effects via `Reader`.
    public init(
        initial: State,
        behavior: Behavior<Action, State, Environment>,
        environment: Environment
    ) {
        self.state = initial
        self.behavior = behavior
        self.environment = environment
    }

    // MARK: - Test API

    /// Dispatches `action` through the behavior, applying the resulting mutation synchronously
    /// and capturing any produced effect into ``pendingEffects``.
    ///
    /// After `send`, inspect ``state`` to verify the mutation and ``pendingEffects`` to verify
    /// that the expected effects were produced.
    ///
    /// - Parameter action: The action to dispatch.
    /// - Returns: `self` for chaining multiple dispatches.
    @discardableResult
    public func send(_ action: Action) -> Self {
        run(DispatchedAction(action))
        return self
    }

    /// Executes all ``pendingEffects`` and appends their output actions to ``receivedActions``.
    ///
    /// After this call, ``pendingEffects`` is empty. Use ``receive()`` to process each
    /// collected action through the behavior.
    ///
    /// Effects are run in order; components within each effect are run sequentially.
    /// Each component is driven to completion before the next one starts, so `await
    /// store.runEffects()` fully drains all pending work.
    public func runEffects() async {
        var toRun: [Effect<Action>] = []
        swap(&toRun, &pendingEffects)
        for effect in toRun {
            for component in effect.components {
                let actions = await drain(component)
                receivedActions.append(contentsOf: actions)
            }
        }
    }

    /// Dequeues and dispatches the next action in ``receivedActions`` through the behavior.
    ///
    /// The action is processed identically to ``send(_:)``: the behavior's handle closure runs,
    /// the resulting mutation updates ``state``, and any produced effect is appended to
    /// ``pendingEffects``.
    ///
    /// - Returns: The action that was processed, or `nil` if ``receivedActions`` is empty.
    @discardableResult
    public func receive() -> Action? {
        guard !receivedActions.isEmpty else { return nil }
        let action = receivedActions.removeFirst()
        run(DispatchedAction(action))
        return action
    }

    // MARK: - Private

    private func run(_ dispatched: DispatchedAction<Action>) {
        let stateAccess = StateAccess { [weak self] in self?.state }
        let consequence = behavior.handle(dispatched, stateAccess)
        consequence.mutation.runEndoMut(&state)
        let effect = consequence.effect.runReader(environment)
        if !effect.components.isEmpty {
            pendingEffects.append(effect)
        }
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
    public convenience init(initial: State, behavior: Behavior<Action, State, Void>) {
        self.init(initial: initial, behavior: behavior, environment: ())
    }

    /// Creates a `TestStore` from a pure ``Reducer`` (no side effects, `Environment == Void`).
    ///
    /// ```swift
    /// let store = TestStore(initial: CounterState(), reducer: counterReducer)
    /// store.send(.increment)
    /// #expect(store.state.count == 1)
    /// ```
    public convenience init(initial: State, reducer: Reducer<Action, State>) {
        self.init(initial: initial, behavior: reducer.asBehavior(), environment: ())
    }
}
