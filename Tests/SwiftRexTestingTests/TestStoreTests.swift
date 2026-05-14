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
    case .increment:    state.count += 1
    case .decrement:    state.count -= 1
    case .set(let v):   state.count = v
    case .load:         state.isLoading = true
    case .loaded(let v):
        state.isLoading = false
        state.count = v
    }
}

// Behavior that combines reducer with a side effect on .load
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
        store.send(.increment)
        #expect(store.state.count == 1)
    }

    @Test func sendDecrement() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.decrement)
        #expect(store.state.count == -1)
    }

    @Test func chainedSends() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment).send(.increment).send(.decrement)
        #expect(store.state.count == 1)
    }

    @Test func setOverridesCount() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment)
        store.send(.set(42))
        #expect(store.state.count == 42)
    }

    @Test func noPendingEffectsForPureReducer() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment)
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }
}

// MARK: - Effect capture tests

@Suite("TestStore — effect capture")
@MainActor
struct TestStoreEffectTests {
    @Test func effectCapturedAsPending() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load)
        #expect(store.state.isLoading)
        #expect(!store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func noEffectForNonMatchingAction() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.increment)
        #expect(store.pendingEffects.isEmpty)
    }
}

// MARK: - runEffects + receive tests

@Suite("TestStore — runEffects + receive")
@MainActor
struct TestStoreRunEffectsTests {
    @Test func runEffectsPopulatesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load)
        await store.runEffects()
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions == [.loaded(99)])
    }

    @Test func receiveProcessesActionThroughBehavior() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load)
        await store.runEffects()
        let action = store.receive()
        #expect(action == .loaded(99))
        #expect(store.state.count == 99)
        #expect(!store.state.isLoading)
    }

    @Test func receiveReturnsNilWhenEmpty() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        #expect(store.receive() == nil)
    }

    @Test func receiveEmptiesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load)
        await store.runEffects()
        store.receive()
        #expect(store.receivedActions.isEmpty)
    }

    @Test func receiveProducedEffectsAreCaptured() async {
        // .loaded produces another .set(100) effect
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
        store.send(.load)
        await store.runEffects()
        store.receive()                // processes .loaded(5) — captures .set(100) effect
        #expect(store.state.count == 5)
        #expect(!store.pendingEffects.isEmpty)

        await store.runEffects()
        store.receive()                // processes .set(100)
        #expect(store.state.count == 100)
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
        let behavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            guard case .load = action.action else { return .doNothing }
            return .produce { _ in combined }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.send(.load)
        await store.runEffects()
        #expect(store.receivedActions.count == 3)
    }

    @Test func runEffectsOnEmptyIsNoop() async {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.send(.increment)
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
        store.send(.set(7))
        #expect(store.state.count == 7)
    }

    @Test func voidBehaviorConvenienceInit() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior)
        store.send(.set(7))
        #expect(store.state.count == 7)
    }

    @Test func fullBehaviorInit() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: ()
        )
        store.send(.set(7))
        #expect(store.state.count == 7)
    }
}
