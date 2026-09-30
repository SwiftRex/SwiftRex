// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

@Suite("StateStream")
@MainActor
struct StateStreamTests {
    private func counterStore(initial: Int = 0) -> Store<Int, Int, Void> {
        Store(initial: initial, reducer: Reducer.reduce { action, state in state += action })
    }

    // MARK: - Delivery

    @Test func observeDeliversTheCurrentValueDuringTheCall() {
        let store = counterStore(initial: 4)
        var received: [Int] = []
        let token = store.stateStream.observe { received.append($0) }
        #expect(received == [4])
        store.dispatch(1)
        #expect(received == [4, 5])
        token.cancel()
    }

    @Test func subscribeReturnsTheCurrentValueAndDeliversOnlyChanges() {
        let store = counterStore(initial: 2)
        var received: [Int] = []
        let (current, token) = store.stateStream.subscribe { received.append($0) }
        #expect(current == 2)
        #expect(received.isEmpty)
        store.dispatch(3)
        #expect(received == [5])
        token.cancel()
    }

    @Test func nothingRunsUntilObserved() {
        let store = counterStore()
        var maps = 0
        let projection = store.projection(action: { $0 }, state: { (s: Int) -> Int in maps += 1; return s * 10 })
        store.dispatch(1)
        store.dispatch(1)
        #expect(maps == 0)
        _ = projection
    }

    // MARK: - Cancellation

    @Test func cancelStopsDeliverySynchronously() {
        let store = counterStore()
        var received: [Int] = []
        let token = store.stateStream.observe { received.append($0) }
        token.cancel()
        store.dispatch(1)
        #expect(received == [0])
    }

    @Test func releasingTheTokenStopsDeliverySynchronously() {
        let store = counterStore()
        var received: [Int] = []
        var token: UISubscriptionToken? = store.stateStream.observe { received.append($0) }
        token = nil
        store.dispatch(1)
        #expect(received == [0])
        _ = token
    }

    @Test func cancelIsIdempotent() {
        var cancels = 0
        let token = UISubscriptionToken { cancels += 1 }
        token.cancel()
        token.cancel()
        #expect(cancels == 1)
    }

    // MARK: - Operators

    @Test func mapRunsOncePerChangePerObserver() {
        let store = counterStore()
        var maps = 0
        let stream = store.stateStream.map { (s: Int) -> Int in maps += 1; return s + 100 }
        var first: [Int] = []
        var second: [Int] = []
        let tokens = [stream.observe { first.append($0) }, stream.observe { second.append($0) }]
        #expect(maps == 2)       // one current value per observer
        store.dispatch(1)
        #expect(maps == 4)       // one per change per observer — no shared cache
        #expect(first == [100, 101])
        #expect(second == [100, 101])
        _ = tokens
    }

    @Test func removeDuplicatesSeedsWithTheCurrentValue() {
        let store = counterStore(initial: 1)
        var received: [Int] = []
        let token = store.stateStream.map { $0 / 10 }.removeDuplicates().observe { received.append($0) }
        store.dispatch(1)        // 2 → 0, same as the seed
        store.dispatch(10)       // 12 → 1
        store.dispatch(1)        // 13 → 1
        #expect(received == [0, 1])
        _ = token
    }

    @Test func removeDuplicatesByPredicate() {
        let store = counterStore()
        var received: [Int] = []
        let token = store.stateStream.removeDuplicates { abs($0 - $1) < 5 }.observe { received.append($0) }
        store.dispatch(2)
        store.dispatch(4)
        #expect(received == [0, 6])
        _ = token
    }

    // MARK: - Stores

    @Test func projectionAndBufferFollowTheStoreAndDispatchThrough() {
        let store = counterStore()
        let doubled = store.projection(action: { $0 }, state: { $0 * 2 }).buffer()
        var received: [Int] = []
        let token = doubled.stateStream.observe { received.append($0) }
        doubled.dispatch(3)
        #expect(received == [0, 6])
        _ = token
    }
}
