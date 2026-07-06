// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Hourglass
import SwiftRex
import SwiftRexTesting
import Testing

// MARK: - Fixtures

// `CounterAction` is written out by hand in the exact shape that `@Prisms` would
// generate, so the tests exercise the same call sites users hit in real code
// (`Action.prism.caseName`, dynamic-member focus access, the `Cases` enum and
// `is(_:)` predicate). Adding `@Prisms` here would be circular for SwiftRex's
// own tests — the macro is built in this same package.
@dynamicMemberLookup
private enum CounterAction: Sendable {
    case increment
    case decrement
    case set(Int)
    case load
    case loaded(Int)
}

extension CounterAction {
    struct Prisms: Sendable {
        let increment: CoreFP.Prism<CounterAction, Void> = CoreFP.prism(
            preview: { (_ s: CounterAction) in guard case .increment = s else { return nil }; return () },
            review: { (_: Void) in CounterAction.increment }
        )
        let decrement: CoreFP.Prism<CounterAction, Void> = CoreFP.prism(
            preview: { (_ s: CounterAction) in guard case .decrement = s else { return nil }; return () },
            review: { (_: Void) in CounterAction.decrement }
        )
        let set: CoreFP.Prism<CounterAction, Int> = CoreFP.prism(
            preview: { (_ s: CounterAction) in guard case let .set(v) = s else { return nil }; return v },
            review: CounterAction.set
        )
        let load: CoreFP.Prism<CounterAction, Void> = CoreFP.prism(
            preview: { (_ s: CounterAction) in guard case .load = s else { return nil }; return () },
            review: { (_: Void) in CounterAction.load }
        )
        let loaded: CoreFP.Prism<CounterAction, Int> = CoreFP.prism(
            preview: { (_ s: CounterAction) in guard case let .loaded(v) = s else { return nil }; return v },
            review: CounterAction.loaded
        )
    }

    static let prism = Prisms()

    /// Dynamic-member focus access: `action.set` is `Int?`, `action.increment` is `Void?`,
    /// matching the subscript the `@Prisms` macro emits when `@dynamicMemberLookup` is set.
    subscript<PrismFocus>(
        dynamicMember keyPath: KeyPath<Prisms, Prism<CounterAction, PrismFocus>>
    ) -> PrismFocus? {
        Self.prism[keyPath: keyPath].preview(self)
    }

    enum Cases: CoreFP.CaseMatchable {
        typealias Subject = CounterAction
        case increment, decrement, set, load, loaded
        func matches(_ value: CounterAction) -> Bool {
            switch (self, value) {
            case (.increment, .increment): true
            case (.decrement, .decrement): true
            case (.set, .set): true
            case (.load, .load): true
            case (.loaded, .loaded): true
            default: false
            }
        }
    }

    func `is`(_ c: Cases) -> Bool { c.matches(self) }
}

private struct CounterState: Equatable, Sendable {
    var count: Int = 0
    var isLoading: Bool = false
}

private let counterReducer = Reducer<CounterAction, CounterState>.reduce { action, state in
    switch action {
    case .increment: state.count += 1
    case .decrement: state.count -= 1
    case let .set(v): state.count = v
    case .load: state.isLoading = true
    case let .loaded(v): state.isLoading = false; state.count = v
    }
}

// Behavior that routes all actions through the reducer and adds a side effect on .load
private let counterBehavior = Behavior<CounterAction, CounterState, Void> { action, _ in
    switch action {
    case .load:
        .reduce { $0.isLoading = true }
            .produce { _ in Effect.just(.loaded(99)) }
    default:
        .reduce { state in counterReducer.reduce(action).runEndoMut(&state) }
    }
}

// MARK: - Pure reducer tests

@Suite("TestStore — reducer")
@MainActor
struct TestStoreReducerTests {
    @Test func sendIncrement() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.dispatch(.increment) { $0.count = 1 }
    }

    @Test func sendDecrement() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.dispatch(.decrement) { $0.count = -1 }
    }

    @Test func chainedSends() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store
            .dispatch(.increment) { $0.count = 1 }
            .dispatch(.increment) { $0.count = 2 }
            .dispatch(.decrement) { $0.count = 1 }
    }

    @Test func setOverridesCount() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.dispatch(.increment) { $0.count = 1 }
        store.dispatch(.set(42)) { $0.count = 42 }
    }

    @Test func noPendingEffectsForPureReducer() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.dispatch(.increment) { $0.count = 1 }
        #expect(store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func stateMismatchRecordsFailure() {
        let store = TestStore(initial: CounterState(), reducer: counterReducer, exhaustive: false)
        withKnownIssue("wrong expected value should record a mismatch failure") {
            store.dispatch(.increment) { $0.count = 99 } // wrong — actual becomes 1
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
        store.dispatch(.load) { $0.isLoading = true }
        #expect(!store.pendingEffects.isEmpty)
        #expect(store.receivedActions.isEmpty)
    }

    @Test func noEffectForNonMatchingAction() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.dispatch(.increment) { $0.count = 1 }
        #expect(store.pendingEffects.isEmpty)
    }

    @Test func sendWithPendingReceivedActionsRecordsFailure() async {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: ()
        )
        store.dispatch(.load) { $0.isLoading = true }
        await store.runEffects()
        withKnownIssue("must process received actions before dispatching again") {
            store.dispatch(.increment) { $0.isLoading = true; $0.count = 1 }
        }
        store.receive(CounterAction.prism.loaded) { value, state in
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
        store.dispatch(.load) { $0.isLoading = true }
        await store.runEffects()
        #expect(store.pendingEffects.isEmpty)
        store.receive(CounterAction.prism.loaded) { value, state in
            state.isLoading = false
            state.count = value // value == 99, extracted from .loaded(99)
        }
    }

    @Test func receiveValidatesActionCaseAndExtractsValue() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.dispatch(.load) { $0.isLoading = true }
        await store.runEffects()
        let action = store.receive(CounterAction.prism.loaded) { value, state in
            #expect(value == 99)
            state.isLoading = false
            state.count = value
        }
        #expect(store.state.count == 99)
        #expect(!store.state.isLoading)
        // Returned action is the dequeued one (for inspection if needed)
        if case let .loaded(v) = action { #expect(v == 99) }
    }

    @Test func receiveWhenEmptyRecordsFailure() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        withKnownIssue("receive() on empty receivedActions should record a failure") {
            store.receive(CounterAction.prism.loaded) { _, _ in }
        }
    }

    @Test func receiveActionMismatchRecordsFailure() async {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        store.dispatch(.load) { $0.isLoading = true }
        await store.runEffects()
        withKnownIssue("wrong prism should record an action-mismatch failure") {
            // Actual action is .loaded(99); prism expects .increment (Void prism)
            store.receive(CounterAction.prism.increment) { _ in }
        }
    }

    @Test func receiveVoidPrism() async {
        // .load produces .increment (a case with no associated value) — exercises the Void overload
        let behavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            switch action {
            case .load:
                .produce { _ in Effect.just(.increment) }
            default:
                .reduce { state in counterReducer.reduce(action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.dispatch(.load) { _ in }
        await store.runEffects()
        // Use the Void-prism overload — no value to extract, just (inout State) -> Void
        store.receive(CounterAction.prism.increment) { $0.count += 1 }
    }

    @Test func receiveEmptiesReceivedActions() async {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior, environment: ())
        store.dispatch(.load) { $0.isLoading = true }
        await store.runEffects()
        store.receive(CounterAction.prism.loaded) { value, state in
            state.isLoading = false; state.count = value
        }
        #expect(store.receivedActions.isEmpty)
    }

    @Test func receiveProducedEffectsAreCaptured() async {
        let chainedBehavior = Behavior<CounterAction, CounterState, Void> { action, _ in
            switch action {
            case .load:
                .reduce { $0.isLoading = true }
                    .produce { _ in Effect.just(.loaded(5)) }
            case let .loaded(v):
                .reduce { state in
                    state.isLoading = false
                    state.count = v
                }.produce { _ in Effect.just(.set(100)) }
            default:
                .reduce { state in counterReducer.reduce(action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: chainedBehavior, environment: ())
        store.dispatch(.load) { $0.isLoading = true }

        await store.runEffects()
        store.receive(CounterAction.prism.loaded) { value, state in
            state.isLoading = false; state.count = value
        }
        #expect(!store.pendingEffects.isEmpty)

        await store.runEffects()
        store.receive(CounterAction.prism.set) { value, state in state.count = value }
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
            switch action {
            case .load: .produce { _ in combined }
            default: .reduce { state in counterReducer.reduce(action).runEndoMut(&state) }
            }
        }
        let store = TestStore(initial: CounterState(), behavior: behavior, environment: ())
        store.dispatch(.load) { _ in }
        await store.runEffects()
        #expect(store.receivedActions.count == 3)
        store.receive(CounterAction.prism.set) { value, state in state.count = value }
        store.receive(CounterAction.prism.set) { value, state in state.count = value }
        store.receive(CounterAction.prism.set) { value, state in state.count = value }
    }

    @Test func runEffectsOnEmptyIsNoop() async {
        let store = TestStore(initial: CounterState(), reducer: counterReducer)
        store.dispatch(.increment) { $0.count = 1 }
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
        store.dispatch(.set(7)) { $0.count = 7 }
    }

    @Test func voidBehaviorConvenienceInit() {
        let store = TestStore(initial: CounterState(), behavior: counterBehavior)
        store.dispatch(.set(7)) { $0.count = 7 }
    }

    @Test func fullBehaviorInit() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: ()
        )
        store.dispatch(.set(7)) { $0.count = 7 }
    }

    @Test func nonExhaustiveSkipsDeinitCheck() {
        let store = TestStore(
            initial: CounterState(),
            behavior: counterBehavior,
            environment: (),
            exhaustive: false
        )
        store.dispatch(.load) { $0.isLoading = true }
        // Pending effect intentionally not drained — non-exhaustive: no deinit failure
    }
}

// MARK: - Prism shape (mirrors @Prisms macro expansion)

@Suite("CounterAction — generated prism surface")
struct CounterActionPrismShapeTests {
    @Test func dynamicMemberFocusExtractsAssociatedValue() {
        #expect(CounterAction.set(42).set == 42)
        #expect(CounterAction.loaded(99).loaded == 99)
        #expect(CounterAction.increment.set == nil)
    }

    @Test func dynamicMemberFocusReturnsVoidForCasesWithoutPayload() {
        #expect(CounterAction.increment.increment != nil)
        #expect(CounterAction.decrement.increment == nil)
    }

    @Test func isPredicateMatchesCaseRegardlessOfPayload() {
        #expect(CounterAction.set(1).is(.set))
        #expect(CounterAction.set(2).is(.set))
        #expect(!CounterAction.set(3).is(.loaded))
        #expect(CounterAction.increment.is(.increment))
    }

    @Test func casesEnumIsCaseIterable() {
        #expect(CounterAction.Cases.allCases.count == 5)
        #expect(CounterAction.Cases.allCases.contains(.set))
        #expect(CounterAction.Cases.allCases.contains(.loaded))
    }

    @Test func reviewReconstructsAction() {
        // `Action.prism.case.review` is the named-case constructor — useful for
        // typed dispatch of cases with associated values.
        let action = CounterAction.prism.loaded.review(7)
        if case let .loaded(v) = action { #expect(v == 7) } else { Issue.record() }
    }
}

// MARK: - Scheduling & channels (driven through the shared EffectEngine)

private enum SocketAction: Sendable, Equatable {
    case connect(Int)
    case received(Int)
    case disconnect
    case ping
    case tick
}

private let socketReceivedPrism = CoreFP.Prism<SocketAction, Int>(
    preview: { if case let .received(v) = $0 { v } else { nil } },
    review: SocketAction.received
)

private let socketTickPrism = CoreFP.Prism<SocketAction, Void>(
    preview: { if case .tick = $0 { () } else { nil } },
    review: { SocketAction.tick }
)

// A long-lived channel keyed "socket" that echoes each piped value back as `.received`.
private let socketBehavior = Behavior<SocketAction, Int, Void> { action, _ in
    switch action {
    case let .connect(n):
        .produce { _ in
            .channel(value: n, scheduling: .keyed(id: "socket")) { send, _ in
                ChannelHandler(receive: { send(.received($0)) }, cancel: {})
            }
        }
    case let .received(v):
        .reduce { $0 = v }
    case .disconnect:
        .produce { _ in .cancel(id: "socket") }
    default:
        .doNothing
    }
}

@Suite("TestStore — scheduling & channels")
@MainActor
struct TestStoreSchedulingTests {
    @Test func channelOpensPipesAndClosesCleanly() async {
        let store = TestStore(initial: 0, behavior: socketBehavior, environment: ())
        store.dispatch(.connect(1)) { _ in } // opens the channel, pipes 1 → send(.received(1))
        await store.runEffects()
        store.receive(socketReceivedPrism) { v, s in s = v }
        #expect(store.state == 1)

        store.dispatch(.connect(2)) { _ in } // pipes 2 into the SAME live channel
        await store.runEffects()
        store.receive(socketReceivedPrism) { v, s in s = v }
        #expect(store.state == 2)

        store.dispatch(.disconnect) { _ in } // cancelInFlight(id: "socket") → closes it
        await store.runEffects()
        // clean end: channel closed, nothing pending — no exhaustive failure
    }

    @Test func openChannelLeftRunningRecordsAnExhaustiveFailure() async {
        await withKnownIssue("a channel left open at end-of-test must be cancelled") {
            let store = TestStore(initial: 0, behavior: socketBehavior, environment: ())
            store.dispatch(.connect(1)) { _ in }
            await store.runEffects()
            store.receive(socketReceivedPrism) { v, s in s = v }
            // never disconnect → channel still open at deinit → failure recorded
        }
    }

    @Test func throttleDropsTheSecondValueOnAFrozenClock() async {
        // ImmediateClock's `now` is frozen, so a throttle window never elapses: the first .tick
        // fires, the second is dropped — exactly what a live Store would do (the miscount fix).
        let store = TestStore(
            initial: 0,
            behavior: Behavior<SocketAction, Int, Void> { action, _ in
                switch action {
                case .ping: .produce { _ in Effect.just(.tick).scheduling(.throttle(id: "t", interval: .seconds(1))) }
                case .tick: .reduce { $0 += 1 }
                default: .doNothing
                }
            },
            environment: ()
        )
        store.dispatch(.ping) { _ in }
        await store.runEffects()
        store.receive(socketTickPrism) { $0 += 1 } // first fires
        #expect(store.state == 1)

        store.dispatch(.ping) { _ in } // within the (frozen) interval → dropped
        await store.runEffects()
        #expect(store.receivedActions.isEmpty) // no spurious second .tick to receive
        #expect(store.state == 1)
    }

    @Test func throttleFiresAgainAfterAdvancingAnInjectedTestClock() async {
        let clock = TestClock()
        let store = TestStore(
            initial: 0,
            behavior: Behavior<SocketAction, Int, Void> { action, _ in
                switch action {
                case .ping: .produce { _ in Effect.just(.tick).scheduling(.throttle(id: "t", interval: .seconds(1))) }
                case .tick: .reduce { $0 += 1 }
                default: .doNothing
                }
            },
            environment: (),
            clock: { _ in clock }
        )
        store.dispatch(.ping) { _ in }
        await store.runEffects()
        store.receive(socketTickPrism) { $0 += 1 }
        #expect(store.state == 1)

        await clock.advance(by: .seconds(1)) // interval elapses on the injected clock
        store.dispatch(.ping) { _ in }
        await store.runEffects()
        store.receive(socketTickPrism) { $0 += 1 } // now fires again
        #expect(store.state == 2)
    }
}
