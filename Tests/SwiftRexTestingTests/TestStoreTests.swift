import CoreFP
import SwiftRex
import SwiftRexTesting
import Testing

// MARK: - Fixtures

private enum CounterAction: Sendable {
    case increment
    case decrement
    case set(Int)
    case load
    case loaded(Int)
}

// Prisms for CounterAction — used in receive() to validate action case + extract value
extension CounterAction {
    enum Prisms {
        static let increment = prism(
            preview: { if case .increment = $0 { return () } else { return nil } },
            review: { _ in CounterAction.increment }
        )
        static let decrement = prism(
            preview: { if case .decrement = $0 { return () } else { return nil } },
            review: { _ in CounterAction.decrement }
        )
        static let set = prism(
            preview: { if case .set(let v) = $0 { return v } else { return nil } },
            review: CounterAction.set
        )
        static let load = prism(
            preview: { if case .load = $0 { return () } else { return nil } },
            review: { _ in CounterAction.load }
        )
        static let loaded = prism(
            preview: { if case .loaded(let v) = $0 { return v } else { return nil } },
            review: CounterAction.loaded
        )
    }
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
        withKnownIssue("must process received actions before dispatching again") {
            store.send(.increment) { $0.isLoading = true; $0.count = 1 }
        }
        store.receive(CounterAction.Prisms.loaded) { value, state in
            state.isLoading = false
            state.count = value
        }
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
        store.receive(CounterAction.Prisms.loaded) { value, state in
            state.isLoading = false
            state.count = value  // value == 99, extracted from .loaded(99)
        }
    }

    @Test func receiveValidatesActionCaseAndExtractsValue() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        let action = store.receive(CounterAction.Prisms.loaded) { value, state in
            #expect(value == 99)
            state.isLoading = false
            state.count = value
        }
        #expect(store.state.count == 99)
        #expect(!store.state.isLoading)
        // Returned action is the dequeued one (for inspection if needed)
        if case .loaded(let v) = action { #expect(v == 99) }
    }

    @Test func receiveWhenEmptyRecordsFailure() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        withKnownIssue("receive() on empty receivedActions should record a failure") {
            store.receive(CounterAction.Prisms.loaded) { _, _ in }
        }
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
        withKnownIssue("wrong prism should record an action-mismatch failure") {
            // Actual action is .loaded(99); prism expects .increment (Void prism)
            store.receive(CounterAction.Prisms.increment) { _ in }
        }
    }

    @Test func receiveVoidPrism() async {
        // .load produces .increment (a case with no associated value) — exercises the Void overload
        let behavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            switch action.action {
            case .load:
                return .produce { _ in Effect.just(.increment) }
            default:
                return .reduce { state in counterReducer.reduce(action.action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.send(.load) { _ in }
        await store.runEffects()
        // Use the Void-prism overload — no value to extract, just (inout State) -> Void
        store.receive(CounterAction.Prisms.increment) { $0.count += 1 }
    }

    @Test func receiveEmptiesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.send(.load) { $0.isLoading = true }
        await store.runEffects()
        store.receive(CounterAction.Prisms.loaded) { value, state in
            state.isLoading = false; state.count = value
        }
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
        store.receive(CounterAction.Prisms.loaded) { value, state in
            state.isLoading = false; state.count = value
        }
        #expect(!store.pendingEffects.isEmpty)

        await store.runEffects()
        store.receive(CounterAction.Prisms.set) { value, state in state.count = value }
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
            switch action.action {
            case .load:   return .produce { _ in combined }
            default:      return .reduce { state in counterReducer.reduce(action.action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.send(.load) { _ in }
        await store.runEffects()
        #expect(store.receivedActions.count == 3)
        store.receive(CounterAction.Prisms.set) { value, state in state.count = value }
        store.receive(CounterAction.Prisms.set) { value, state in state.count = value }
        store.receive(CounterAction.Prisms.set) { value, state in state.count = value }
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
        // Pending effect intentionally not drained — non-exhaustive: no deinit failure
    }
}
