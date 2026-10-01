import Benchmark
import CoreFP
import SwiftRex

// Store, StoreProjection and StoreBuffer are all `@MainActor`, so these run the measured loop
// inside a single `MainActor.run` hop (amortised across all scaled iterations). `scaledIterations`
// is captured before the hop so the non-Sendable `benchmark` never crosses the actor boundary.
// Behaviors used here are effect-free, so each `dispatch` completes synchronously on the main actor.
// Stores can't be read, only followed: each benchmark keeps one observer on the stream, as a view would.

func storeDispatchBenchmarks() {
    // End-to-end dispatch through the full three-phase pipeline (DispatchedAction wrapping,
    // phase 1 handle, phase 2 mutation, one stream observer) — the real per-action cost.
    Benchmark("Store.dispatch — reducer only") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store = Store(initial: BenchState(), reducer: tickReducer)
            let token = store.stateStream.observe { blackHole($0.counter) }
            for _ in iterations {
                store.dispatch(.tick)
            }
            token.cancel()
        }
    }

    // Same, but the behavior is reducer + (identity) middleware — isolates the cost of routing
    // through the Consequence's effect half vs the reducer-only path above.
    Benchmark("Store.dispatch — reducer + middleware") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store: Store<BenchAction, BenchState, Void> = Store(
                initial: BenchState(),
                reducer: tickReducer,
                middleware: Middleware.identity,
                environment: ()
            )
            let token = store.stateStream.observe { blackHole($0.counter) }
            for _ in iterations {
                store.dispatch(.tick)
            }
            token.cancel()
        }
    }

    // Dispatch through 8 combined behaviors — exercises Behavior.combine / Consequence.combine
    // execution (each phase-1 handle runs and the consequences are merged) per dispatch.
    let combinedBehavior: Behavior<BenchAction, BenchState, Void> =
        mconcat(Array(repeating: tickReducer.asBehavior(), count: 8))
    Benchmark("Store.dispatch — combined behavior x8") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store: Store<BenchAction, BenchState, Void> = Store(initial: BenchState(), behavior: combinedBehavior)
            let token = store.stateStream.observe { blackHole($0.counter) }
            for _ in iterations {
                store.dispatch(.tick)
            }
            token.cancel()
        }
    }
}

func storeReadBenchmarks() {
    // StoreCollectionFocus element lookup — a NEW observer starts with an empty hint and searches outward from the
    // start: O(n) for the last of 1,000 elements. Measured through the current value a new observer receives (an
    // existing observer keeps its hint: O(distance moved) per change).
    let targetId = collectionSize - 1
    Benchmark("StoreCollectionFocus current value — by id in \(collectionSize)") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store: Store<ListAction, ListState, Void> = Store(initial: makeList(collectionSize), reducer: .identity)
            let projection = store.projection(itemScope, element: targetId)
            for _ in iterations {
                blackHole(projection.stateStream.subscribe { _ in }.current?.n)
            }
        }
    }

    // Dispatch through a StoreBuffer — the underlying mutation reaches the buffer's stream, which runs its
    // `hasChanged` (Equatable) predicate before passing the state on. Measures the dedup path.
    Benchmark("StoreBuffer.dispatch — gated") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store = Store(initial: BenchState(), reducer: tickReducer)
            let buffer = StoreBuffer(store)
            let token = buffer.stateStream.observe { blackHole($0.counter) }
            for _ in iterations {
                buffer.dispatch(.tick)
            }
            token.cancel()
        }
    }
}
