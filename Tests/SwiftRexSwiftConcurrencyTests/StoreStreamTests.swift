// SPDX-License-Identifier: Apache-2.0

import SwiftRex
@testable import SwiftRexSwiftConcurrency
import Testing

@Suite
@MainActor
struct StoreStreamTests {
    /// `store.stream()` is a lazy factory: each call starts a fresh observation that yields the
    /// store's state after every mutation.
    @Test func streamYieldsStateAfterMutation() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        let received = LockProtected([Int]())

        let task = Task {
            for await state in store.stream() {
                received.mutate { $0.append(state) }
                if state == 5 { break }
            }
        }

        // Let the observer register (registration hops through a Task), then mutate.
        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = store.dispatch(5)
        try? await Task.sleep(nanoseconds: 100_000_000)

        task.cancel()
        #expect(received.value.contains(5))
    }

    /// The factory is independent per call — two `stream()` iterations each observe on their own.
    @Test func eachStreamCallIsIndependent() async {
        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { action, state in state += action })
        let first = LockProtected(false)
        let second = LockProtected(false)

        let t1 = Task {
            for await state in store.stream() where state == 3 {
                first.set(true); break
            }
        }
        let t2 = Task {
            for await state in store.stream() where state == 3 {
                second.set(true); break
            }
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = store.dispatch(3)
        try? await Task.sleep(nanoseconds: 100_000_000)

        t1.cancel()
        t2.cancel()
        #expect(first.value)
        #expect(second.value)
    }
}
