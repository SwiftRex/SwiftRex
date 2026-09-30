// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

@Suite("StoreBuffer")
@MainActor
struct StoreBufferTests {
    private func counterStore(initial: Int = 0) -> Store<Int, Int, Void> {
        Store(initial: initial, reducer: Reducer.reduce { action, state in state += action })
    }

    // MARK: - State caching

    @Test func initialStateMatchesUnderlyingStore() {
        let store = counterStore(initial: 7)
        let buffer = StoreBuffer(store, hasChanged: !=)
        #expect(buffer.currentState == 7)
    }

    @Test func stateUpdatesWhenPredicatePasses() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        store.dispatch(5)
        #expect(buffer.currentState == 5)
    }

    @Test func stateDoesNotUpdateWhenPredicateFails() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: { _, _ in false })
        var received: [Int] = []
        let token = buffer.stateStream.observe { received.append($0) }
        store.dispatch(5)
        #expect(received == [0])
        _ = token
    }

    @Test func equatableConvenienceInitUsesNotEqual() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store) // uses !=
        store.dispatch(3)
        #expect(buffer.currentState == 3)
    }

    // MARK: - Observers

    @Test func passesAChangeWhenThePredicatePasses() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        let count = LockProtected(0)
        let token = buffer.stateStream.subscribe { _ in count.mutate { $0 += 1 } }.token
        store.dispatch(1)
        #expect(count.value == 1)
        withExtendedLifetime(token) {}
    }

    @Test func dropsAChangeWhenThePredicateFails() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: { _, _ in false })
        let count = LockProtected(0)
        let token = buffer.stateStream.subscribe { _ in count.mutate { $0 += 1 } }.token
        store.dispatch(1)
        #expect(count.value == 0)
        withExtendedLifetime(token) {}
    }

    @Test func deliversTheNewState() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        var seen: [Int] = []
        let token = buffer.stateStream.observe { seen.append($0) }
        store.dispatch(10)
        #expect(seen == [0, 10])
        withExtendedLifetime(token) {}
    }

    @Test func equatableBufferSkipsEqualStates() {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state = action })
        let count = LockProtected(0)
        let token = store.buffer().stateStream.subscribe { _ in count.mutate { $0 += 1 } }.token
        store.dispatch(0) // same value
        store.dispatch(3)
        store.dispatch(3) // same again
        #expect(count.value == 1)
        withExtendedLifetime(token) {}
    }

    @Test func dispatchForwardsToUnderlyingStore() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        buffer.dispatch(4)
        #expect(store.currentState == 4)
    }

    // MARK: - Custom predicate (only fire on specific change)

    @Test func customPredicateOnlyFiresForLargeChanges() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store) { old, new in abs(new - old) >= 10 }
        let count = LockProtected(0)
        let token = buffer.stateStream.subscribe { _ in count.mutate { $0 += 1 } }.token
        store.dispatch(5) // change of 5 — below threshold
        store.dispatch(10) // 15, a change of 15 from the last passed value (0) — at threshold
        #expect(count.value == 1) // only the second dispatch passed
        withExtendedLifetime(token) {}
    }
}
