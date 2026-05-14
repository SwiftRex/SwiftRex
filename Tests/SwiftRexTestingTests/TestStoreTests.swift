import SwiftRex
import SwiftRexTesting
import Testing

// MARK: - Fixtures

private enum CounterAction: Equatable, Sendable {
    case increment
    case decrement
    case set(Int)
    case load
    case loaded(Int)
}

private struct CounterState: Equatable, Sendable {
    var count: Int = 0
    var isLoading: Bool = false
}

private let counterReducer = Reducer<CounterAction, CounterState>.reduce { action, state in
    switch action {
    case .increment:     state.count += 1
    case .decrement:     state.count -= 1
    case .set(let v):    state.count = v
    case .load:          state.isLoading = true
    case .loaded(let v): state.isLoading = false; state.count = v
    }
}

// Behavior that routes all actions through the reducer and adds a side effect on .load
private let counterBehavior = Behavior<CounterAction, CounterState, Void> { action, _ in
    switch action.action {
    case .load:
        return .reduce { $0.isLoading = true }
               .produce { _ in Effect.just(.loaded(99)) }
    default:
        return .reduce { state in counterReducer.reduce(action.action).runEndoMut(&state) }
    }
}

// MARK: - Pure reducer tests

@Suite("TestStore — reducer")
@MainActor
struct TestStoreReducerTests {
    @Test func sendIncrement() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment) { $0.count = 1 }
    }

    @Test func sendDecrement() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.decrement) { $0.count = -1 }
    }

    @Test func chainedSends() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store
            .send(.increment) { $0.count = 1 }
            .send(.increment) { $0.count = 2 }
            .send(.decrement) { $0.count = 1 }
    }

    @Test func setOverridesCount() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment) { $0.count = 1 }
        store.send(.set(42)) { $0.count = 42 }
    }

    @Test func noPendingEffectsForPureReducer() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment) { $0.count = 1 }
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func stateMismatchRecordsFailure() {
        // non-exhaustive so deinit doesn't add noise
        let store = TestStore(initial: CounterState(), reducer: counterReducer, exhaustive: false)
        withKnownIssue("wrong expected value should record a mismatch failure") {
            store.send(.increment) { $0.count = 99 }  // wrong — actual becomes 1
        }
        #expect(store.state.count == 1)
    }
}

// MARK: - Effect capture tests

@Suite("TestStore — effect capture")
@MainActor
struct TestStoreEffectTests {
    @Test func effectCapturedAsPending() {
        // non-exhaustive so the un-drained effect doesn't fail at deinit
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        store.send(.load) { $0.isLoading = true }
        #expect(!store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func noEffectForNonMatchingAction() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.increment) { $0.count = 1 }
        #expect(store.pendingEffects.isEmpty)
    }

    @Test func sendWithPendingReceivedActionsRecordsFailure() async {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: ()
        )
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        // receivedActions = [.loaded(99)]; calling send now should record a failure
        withKnownIssue("must process received actions before dispatching again") {
            store.send(.increment) { $0.isLoading = true; $0.count = 1 }
        }
        // process the pending received action so deinit is clean
        store.receive(.loaded(99)) { $0.isLoading = false; $0.count = 99 }
    }
}

// MARK: - runEffects + receive tests

@Suite("TestStore — runEffects + receive")
@MainActor
struct TestStoreRunEffectsTests {
    @Test func runEffectsPopulatesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions == [.loaded(99)])
        store.receive(.loaded(99)) { $0.isLoading = false; $0.count = 99 }
    }

    @Test func receiveProcessesActionThroughBehavior() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        let action = store.receive(.loaded(99)) { $0.isLoading = false; $0.count = 99 }
        #expect(action == .loaded(99))
    }

    @Test func receiveWhenEmptyRecordsFailure() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        withKnownIssue("receive() on empty receivedActions should record a failure") {
            let result = store.receive(.loaded(0)) { _ in }
            #expect(result == nil)
        }
    }

    @Test func receiveEmptiesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        store.receive(.loaded(99)) { $0.isLoading = false; $0.count = 99 }
        #expect(store.receivedActions.isEmpty)
    }

    @Test func receiveProducedEffectsAreCaptured() async {
        let chainedBehavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            switch action.action {
            case .load:
                return .reduce { $0.isLoading = true }
                       .produce { _ in Effect.just(.loaded(5)) }
            case .loaded(let v):
                return .reduce { state in
                    state.isLoading = false
                    state.count = v
                }.produce { _ in Effect.just(.set(100)) }
            default:
                return .reduce { state in counterReducer.reduce(action.action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: chainedBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }

        await store.runEffects()
        store.receive(.loaded(5)) { $0.isLoading = false; $0.count = 5 }
        #expect(!store.pendingEffects.isEmpty)

        await store.runEffects()
        store.receive(.set(100)) { $0.count = 100 }
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func multiComponentEffectDrainsCompletely() async {
        let combined = Effect.combine(
            Effect.combine(
                Effect<CounterAction>.just(.set(1)),
                Effect<CounterAction>.just(.set(2))
            ),
            Effect<CounterAction>.just(.set(3))
        )
        // Behavior handles .load (effect) + all others via reducer
        let behavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            switch action.action {
            case .load:
                return .produce { _ in combined }
            default:
                return .reduce { state in counterReducer.reduce(action.action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.send(.load) { _ in }  // .load produces no state change in this behavior
        await store.runEffects()
        #expect(store.receivedActions.count == 3)
        store.receive(.set(1)) { $0.count = 1 }
        store.receive(.set(2)) { $0.count = 2 }
        store.receive(.set(3)) { $0.count = 3 }
    }

    @Test func receiveActionMismatchRecordsFailure() async {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        withKnownIssue("wrong expected action should record a mismatch failure") {
            store.receive(.increment) { $0.isLoading = false; $0.count = 99 }
        }
    }

    @Test func runEffectsOnEmptyIsNoop() async {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment) { $0.count = 1 }
        await store.runEffects()
        #expect(store.receivedActions.isEmpty)
    }
}

// MARK: - Init variants

@Suite("TestStore — init variants")
@MainActor
struct TestStoreInitTests {
    @Test func reducerConvenienceInit() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.set(7)) { $0.count = 7 }
    }

    @Test func voidBehaviorConvenienceInit() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior)
        store.send(.set(7)) { $0.count = 7 }
    }

    @Test func fullBehaviorInit() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: ()
        )
        store.send(.set(7)) { $0.count = 7 }
    }

    @Test func nonExhaustiveSkipsDeinitCheck() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        store.send(.load) { $0.isLoading = true }
        // Pending effect intentionally not drained — non-exhaustive mode means no deinit failure
    }
}
