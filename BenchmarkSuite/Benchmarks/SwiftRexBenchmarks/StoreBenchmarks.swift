import Benchmark
import CoreFP
import SwiftRex

// Store, StoreProjection and StoreBuffer are all `@MainActor`, so these run the measured loop
// inside a single `MainActor.run` hop (amortised across all scaled iterations). `scaledIterations`
// is captured before the hop so the non-Sendable `benchmark` never crosses the actor boundary.
// Behaviors used here are effect-free, so each `dispatch` completes synchronously on the main actor.

func storeDispatchBenchmarks() {
    // End-to-end dispatch through the full three-phase pipeline (DispatchedAction wrapping,
    // phase 1 handle, phase 2 mutation, observer hooks) — the real per-action cost.
    Benchmark("Store.dispatch — reducer only") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store = Store(initial: BenchState(), reducer: tickReducer)
            for _ in iterations {
                store.dispatch(.tick)
                blackHole(store.state.counter)
            }
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
            for _ in iterations {
                store.dispatch(.tick)
                blackHole(store.state.counter)
            }
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
            for _ in iterations {
                store.dispatch(.tick)
                blackHole(store.state.counter)
            }
        }
    }
}

func storeReadBenchmarks() {
    // StoreProjection element read — `state` recomputes `collection.first { id matches }` on every
    // access: O(n) per read over a 1,000-element collection. This is roadmap item 23's baseline.
    let targetId = collectionSize - 1
    Benchmark("StoreProjection.state — by id in \(collectionSize)") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store: Store<ListAction, ListState, Void> = Store(initial: makeList(collectionSize), reducer: .identity)
            let projection = StoreProjection<ItemAction, Item?>(
                store: store,
                element: targetId,
                actionReview: { (ea: ElementAction<Int, ItemAction>) in ListAction.item(ea) },
                stateCollection: \ListState.items,
                identifier: { (item: Item) in item.id }
            )
            for _ in iterations {
                blackHole(projection.state?.n)
            }
        }
    }

    // Dispatch through a StoreBuffer — the underlying mutation fires `didChange`, the buffer runs
    // its `hasChanged` (Equatable) predicate and gates its own observers. Measures the dedup path.
    Benchmark("StoreBuffer.dispatch — gated") { benchmark in
        let iterations = benchmark.scaledIterations
        await MainActor.run {
            let store = Store(initial: BenchState(), reducer: tickReducer)
            let buffer = StoreBuffer(store)
            for _ in iterations {
                buffer.dispatch(.tick)
                blackHole(buffer.state.counter)
            }
        }
    }
}
