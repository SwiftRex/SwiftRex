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
        #expect(buffer.state == 7)
    }

    @Test func stateUpdatesWhenPredicatePasses() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        store.dispatch(5)
        #expect(buffer.state == 5)
    }

    @Test func stateDoesNotUpdateWhenPredicateFails() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: { _, _ in false })
        store.dispatch(5)
        #expect(buffer.state == 0)
    }

    @Test func equatableConvenienceInitUsesNotEqual() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store) // uses !=
        store.dispatch(3)
        #expect(buffer.state == 3)
    }

    // MARK: - Observers

    @Test func didChangeFiresWhenPredicatePasses() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        let count = LockProtected(0)
        _ = buffer.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        #expect(count.value == 1)
    }

    @Test func didChangeDoesNotFireWhenPredicateFails() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: { _, _ in false })
        let count = LockProtected(0)
        _ = buffer.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(1)
        #expect(count.value == 0)
    }

    @Test func willChangeFiresBeforeStateUpdates() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        var stateAtWillChange = -1
        _ = buffer.observe(
            willChange: { stateAtWillChange = buffer.state },
            didChange: {}
        )
        store.dispatch(10)
        #expect(stateAtWillChange == 0) // old state before buffer updates
    }

    @Test func didChangeFiresAfterStateUpdates() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        var stateAtDidChange = -1
        _ = buffer.observe(
            willChange: {},
            didChange: { stateAtDidChange = buffer.state }
        )
        store.dispatch(10)
        #expect(stateAtDidChange == 10)
    }

    @Test func dispatchForwardsToUnderlyingStore() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store, hasChanged: !=)
        buffer.dispatch(4)
        #expect(store.state == 4)
    }

    // MARK: - Custom predicate (only fire on specific change)

    @Test func customPredicateOnlyFiresForLargeChanges() {
        let store = counterStore(initial: 0)
        let buffer = StoreBuffer(store) { old, new in abs(new - old) >= 10 }
        let count = LockProtected(0)
        _ = buffer.observe(willChange: {}, didChange: { count.mutate { $0 += 1 } })
        store.dispatch(5)  // change of 5 — below threshold
        store.dispatch(10) // change of 10 from buffer.state=0 — at threshold
        #expect(count.value == 1) // only the second dispatch fired
    }
}
