import Benchmark
import CoreFP
import SwiftRex

let benchmarks: @Sendable () -> Void = {
    reduceBenchmarks()
    liftBenchmarks()
    storeDispatchBenchmarks()
    storeReadBenchmarks()
}

// MARK: - Reducer / EndoMut (synchronous reduce path)

func reduceBenchmarks() {
    // Single-reducer dispatch throughput — the synchronous hot path
    // (`reduce(action).runEndoMut(&state)`) the Store runs in phase 2 of every dispatch.
    Benchmark("Reducer.reduce — single") { benchmark in
        var state = BenchState()
        for _ in benchmark.scaledIterations {
            tickReducer.reduce(.tick).runEndoMut(&state)
            blackHole(state.counter)
        }
    }

    // Composition of 64 reducers via `mconcat` — the N-deep closure tree that roadmap item 21
    // (flat array-based folds) aims to flatten. This is the before-baseline.
    let combined = mconcat(Array(repeating: tickReducer, count: 64))
    Benchmark("Reducer.combine x64 — reduce") { benchmark in
        var state = BenchState()
        for _ in benchmark.scaledIterations {
            combined.reduce(.tick).runEndoMut(&state)
            blackHole(state.counter)
        }
    }

    // EndoMut zero-copy guard: apply a scalar-field mutation to a state holding a large array.
    // EndoMut runs the mutation through `inout`, so `payload` must NOT be copied — its wall
    // clock should track the raw control below, independent of array size.
    Benchmark(
        "EndoMut zero-copy — large state",
        configuration: .init(metrics: [.wallClock, .throughput, .mallocCountTotal])
    ) { benchmark in
        let mutate = tickReducer.reduce(.tick)
        var state = BenchState(payload: Array(0..<largePayloadSize))
        for _ in benchmark.scaledIterations {
            mutate.runEndoMut(&state)
            blackHole(state.counter)
        }
    }

    // Raw in-place field mutation — the zero-copy reference for the benchmark above. #3 staying
    // level with this confirms the EndoMut abstraction adds no array-size-proportional cost.
    Benchmark(
        "EndoMut zero-copy — raw control",
        configuration: .init(metrics: [.wallClock, .throughput, .mallocCountTotal])
    ) { benchmark in
        var state = BenchState(payload: Array(0..<largePayloadSize))
        for _ in benchmark.scaledIterations {
            state.counter += 1
            blackHole(state.counter)
        }
    }
}

// MARK: - lift / liftEach / liftCollection (optic cost per dispatch)

func liftBenchmarks() {
    // Single-target lift through getter/setter closures (the Lens path). Measures the per-dispatch
    // optic overhead vs the un-lifted `Reducer.reduce — single` baseline.
    let lifted = tickReducer.lift(
        actionGetter: { (g: GlobalAction) -> BenchAction? in
            if case .local(let a) = g { a } else { nil }
        },
        stateGetter: { (g: GlobalState) in g.local },
        stateSetter: { (g: inout GlobalState, s: BenchState) in g.local = s }
    )
    Benchmark("Reducer.lift — single target") { benchmark in
        var state = GlobalState()
        for _ in benchmark.scaledIterations {
            lifted.reduce(.local(.tick)).runEndoMut(&state)
            blackHole(state.local.counter)
        }
    }

    // Broadcast to EVERY element of a 1,000-element collection — O(n) per dispatch.
    let liftedEach = itemReducer.liftEach(
        action: { (a: ListAction) -> ItemAction? in
            if case .bumpAll = a { .bump } else { nil }
        },
        stateCollection: \ListState.items
    )
    Benchmark("Reducer.liftEach — broadcast \(collectionSize)") { benchmark in
        var state = makeList(collectionSize)
        for _ in benchmark.scaledIterations {
            liftedEach.reduce(.bumpAll).runEndoMut(&state)
            blackHole(state.items[0].n)
        }
    }

    // Target ONE element by id in a 1,000-element collection — O(n) lookup per dispatch.
    let liftedColl = itemReducer.liftCollection(
        action: { (a: ListAction) -> ElementAction<Int, ItemAction>? in
            if case .item(let ea) = a { ea } else { nil }
        },
        stateCollection: \ListState.items,
        identifier: { (item: Item) in item.id }
    )
    let targetId = collectionSize - 1
    Benchmark("Reducer.liftCollection — by id in \(collectionSize)") { benchmark in
        var state = makeList(collectionSize)
        for _ in benchmark.scaledIterations {
            liftedColl.reduce(.item(ElementAction(targetId, action: .bump))).runEndoMut(&state)
            blackHole(state.items[targetId].n)
        }
    }
}
