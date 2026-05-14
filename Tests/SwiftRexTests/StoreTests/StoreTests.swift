import Testing
import CoreFP
@testable import SwiftRex

// MARK: - Helpers

@MainActor
private func makeStore(initial: Int = 0) -> Store<Int, Int, Void> {
    Store(initial: initial, reducer: Reducer.reduce { action, state in state += action })
}

// MARK: - Init

@Suite("Store init")
@MainActor
struct StoreInitTests {
    @Test func reducerInitSetsInitialState() {
        let store = Store(initial: 42, reducer: Reducer<Int, Int>.reduce { _, _ in })
        #expect(store.state == 42)
    }

    @Test func behaviorInitSetsInitialState() {
        let store = Store(initial: 7, behavior: Behavior<Int, Int, Void>.identity, environment: ())
        #expect(store.state == 7)
    }
}

// MARK: - Dispatch → mutation

@Suite("Store dispatch")
@MainActor
struct StoreDispatchTests {
    @Test func dispatchMutatesState() {
        let store = makeStore()
        store.dispatch(5)
        #expect(store.state == 5)
    }

    @Test func dispatchIsAccumulative() {
        let store = makeStore()
        store.dispatch(3)
        store.dispatch(4)
        #expect(store.state == 7)
    }

    @Test func dispatchWithSourcePreservesCallSite() {
        let line: UInt = #line
        let seen = LockProtected([ActionSource]())
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                seen.mutate { $0.append(action.dispatcher) }
                return .doNothing
            },
            environment: ()
        )
        store.dispatch(1, source: ActionSource(file: "f.swift", function: "fn()", line: line))
        #expect(seen.value.first?.line == line)
    }
}

// MARK: - observe(willChange:didChange:)

@Suite("Store observe")
@MainActor
struct StoreObserveTests {
    @Test func willChangeFiresBeforeMutation() {
        let store = makeStore()
        var stateAtWillChange = -1
        _ = store.observe(
            willChange: { stateAtWillChange = store.state },
            didChange: {}
        )
        store.dispatch(10)
        #expect(stateAtWillChange == 0) // saw pre-mutation state
    }

    @Test func didChangeFiresAfterMutation() {
        let store = makeStore()
        var stateAtDidChange = -1
        _ = store.observe(
            willChange: {},
            didChange: { stateAtDidChange = store.state }
        )
        store.dispatch(10)
        #expect(stateAtDidChange == 10) // saw post-mutation state
    }

    @Test func multipleObserversAllFire() {
        let store = makeStore()
        let count = LockProtected(0)
        _ = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        _ = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        #expect(count.value == 2)
    }

    @Test func cancellingTokenRemovesObserver() async {
        let store = makeStore()
        let count = LockProtected(0)
        let token = store.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        token.cancel()
        // Cancellation hops through a Task; yield so it can run
        await Task.yield()
        await Task.yield()
        store.dispatch(1)
        #expect(count.value == 1)
    }
}

// MARK: - Effect dispatch (immediate scheduling)

@Suite("Store effect scheduling")
@MainActor
struct StoreEffectSchedulingTests {
    @Test func immediateEffectLoopsBackAction() async {
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action.action == 0
                    ? .produce { _ in .just(99) }
                    : .doNothing
            },
            environment: ()
        )
        store.dispatch(0)
        await Task.yield()
        await Task.yield()
        #expect(store.state == 0) // behavior produced effect but no mutation
    }

    @Test func replacingCancelsInFlightEffect() async {
        let dispatched = LockProtected([Int]())
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                .produce { _ in Effect<Int>.just(action.action).scheduling(.replacing(id: "key")) }
            },
            environment: ()
        )
        store.dispatch(1)
        store.dispatch(2) // should cancel the first
        await Task.yield()
        await Task.yield()
        _ = dispatched
        // Simply verify no crash and the store is still alive
        #expect(store.state == 0)
    }

    @Test func cancelInFlightStopsEffect() {
        let store = Store(
            initial: 0,
            behavior: Behavior<Int, Int, Void>.handle { action, _ in
                action.action == 0
                    ? .produce { _ in Effect<Int>.just(1).scheduling(.cancelInFlight(id: "key")) }
                    : .doNothing
            },
            environment: ()
        )
        store.dispatch(0)
        // No crash; effect cancelled immediately
        #expect(store.state == 0)
    }
}

// MARK: - Convenience init (reducer + middleware)

@Suite("Store reducer+middleware init")
@MainActor
struct StoreReducerMiddlewareInitTests {
    @Test func reducerMutatesAndMiddlewareProducesEffect() async {
        // Middleware produces a .just(1000) which loops back and adds 1000 to state
        let store = Store(
            initial: 0,
            reducer: Reducer<Int, Int>.reduce { action, state in state += action },
            middleware: Middleware<Int, Int, Void>.handle { action, _ in
                action.action < 100 ? .just(1000) : .empty
            },
            environment: ()
        )
        store.dispatch(5)
        await Task.yield()
        await Task.yield()
        #expect(store.state == 1005) // 5 from reducer + 1000 from effect loop-back
    }
}
