import CoreFP
import SwiftRex

// MARK: - Single-feature fixtures

struct BenchState: Sendable, Equatable {
    var counter: Int = 0
    // A large copy-on-write array used to detect accidental whole-state copies.
    var payload: [Int] = []
}

enum BenchAction: Sendable {
    case tick
}

// A trivial leaf reducer that mutates only the scalar field, leaving `payload` untouched.
let tickReducer = Reducer<BenchAction, BenchState>.reduce { _, state in
    state.counter += 1
}

// 800 KB of Ints — large enough that a stray whole-array copy would dominate wall clock.
let largePayloadSize = 100_000

// MARK: - Collection fixtures (lift / liftEach / liftCollection / projection)

struct Item: Sendable, Equatable {
    var id: Int
    var n: Int = 0
}

enum ItemAction: Sendable {
    case bump
}

let itemReducer = Reducer<ItemAction, Item>.reduce { _, item in
    item.n += 1
}

struct ListState: Sendable, Equatable {
    var items: [Item]
}

enum ListAction: Sendable {
    case bumpAll
    case item(ElementAction<Int, ItemAction>)
}

// A list of `count` items with ids 0..<count.
func makeList(_ count: Int) -> ListState {
    ListState(items: (0..<count).map { Item(id: $0) })
}

let collectionSize = 1_000

// MARK: - Global fixtures (single-target lift)

struct GlobalState: Sendable, Equatable {
    var local: BenchState = .init()
    var other: Int = 0
}

enum GlobalAction: Sendable {
    case local(BenchAction)
    case other
}
