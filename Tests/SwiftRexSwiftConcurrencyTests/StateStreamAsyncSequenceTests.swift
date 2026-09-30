// SPDX-License-Identifier: Apache-2.0

import SwiftRex
import Testing

/// `StateStream` is an `AsyncSequence` iterated from the main actor: the current state first, then the newest
/// state each time the loop asks — a slow loop skips intermediate states rather than queueing them.
@Suite
@MainActor
struct StateStreamAsyncSequenceTests {
    @Test func yieldsTheCurrentStateThenChanges() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        var iterator = store.stateStream.makeAsyncIterator()
        #expect(await iterator.next() == 0)
        store.dispatch(5)
        #expect(await iterator.next() == 5)
    }

    @Test func aSlowConsumerOnlySeesTheLatestState() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        var iterator = store.stateStream.makeAsyncIterator()
        #expect(await iterator.next() == 0)
        store.dispatch(1)
        store.dispatch(2)
        store.dispatch(3) // three changes while the loop wasn't asking
        #expect(await iterator.next() == 6) // only the newest
    }

    @Test func forAwaitFromTheMainActor() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        let task = Task { @MainActor in
            var seen: [Int] = []
            for await state in store.stateStream {
                seen.append(state)
                if state == 3 { break }
            }
            return seen
        }
        await Task.yield()
        store.dispatch(3)
        #expect(await task.value == [0, 3])
    }

    @Test func eachIterationIsIndependent() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        var first = store.stateStream.makeAsyncIterator()
        var second = store.stateStream.makeAsyncIterator()
        #expect(await first.next() == 0)
        store.dispatch(2)
        #expect(await first.next() == 2)
        #expect(await second.next() == 2) // its own pending value: the latest
    }
}
