import Benchmark
import CoreFP
import SwiftRex

// MARK: - Fixtures

private struct BenchState: Sendable {
    var counter: Int = 0
    // A large copy-on-write array used to detect accidental whole-state copies.
    var payload: [Int]
}

private enum BenchAction: Sendable {
    case tick
}

// A trivial leaf reducer that mutates only the scalar field, leaving `payload` untouched.
private let tickReducer = Reducer<BenchAction, BenchState>.reduce { _, state in
    state.counter += 1
}

// 800 KB of Ints — large enough that a stray whole-array copy would dominate wall clock.
private let largePayloadSize = 100_000

// MARK: - Benchmarks

let benchmarks: @Sendable () -> Void = {
    // 1. Single-reducer dispatch throughput — the synchronous hot path
    //    (`reduce(action).runEndoMut(&state)`) the Store runs in phase 2 of every dispatch.
    Benchmark("Reducer.reduce — single") { benchmark in
        var state = BenchState(payload: [])
        for _ in benchmark.scaledIterations {
            tickReducer.reduce(.tick).runEndoMut(&state)
            blackHole(state.counter)
        }
    }

    // 2. Composition of 64 reducers via `mconcat` — the N-deep closure tree that roadmap
    //    item 21 (flat array-based folds) aims to flatten. This is the before-baseline.
    let combined = mconcat(Array(repeating: tickReducer, count: 64))
    Benchmark("Reducer.combine x64 — reduce") { benchmark in
        var state = BenchState(payload: [])
        for _ in benchmark.scaledIterations {
            combined.reduce(.tick).runEndoMut(&state)
            blackHole(state.counter)
        }
    }

    // 3. EndoMut zero-copy guard: apply a scalar-field mutation to a state holding a large
    //    array. EndoMut runs the mutation through `inout`, so `payload` must NOT be copied —
    //    its wall clock should track the raw control below (#4), independent of array size.
    //    A regression to whole-state copying would make this scale with `largePayloadSize`.
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

    // 4. Raw in-place field mutation — the zero-copy reference for #3. Same state shape,
    //    no EndoMut. #3 staying level with this confirms the EndoMut abstraction adds no
    //    array-size-proportional cost.
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
