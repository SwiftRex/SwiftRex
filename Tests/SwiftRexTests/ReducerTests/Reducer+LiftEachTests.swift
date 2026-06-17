import CoreFP
@testable import SwiftRex
import Testing

@Suite
struct ReducerLiftEachTests {
    private struct AppState: Equatable {
        var nums: [Int] = []
        var lookup: [String: Int] = [:]
    }

    private enum AppAction {
        case bumpAll(Int)
        case other
    }

    private let bump = Reducer<Int, Int>.reduce { delta, n in n += delta }

    private func delta(_ action: AppAction) -> Int? {
        guard case .bumpAll(let d) = action else { return nil }
        return d
    }

    @Test func broadcastsToEveryArrayElement() {
        let lifted = bump.liftEach(action: delta, stateCollection: \AppState.nums)
        var state = AppState(nums: [1, 2, 3])
        lifted.reduce(.bumpAll(10))(&state)
        #expect(state.nums == [11, 12, 13])
    }

    @Test func ignoresUnmatchedAction() {
        let lifted = bump.liftEach(action: delta, stateCollection: \AppState.nums)
        var state = AppState(nums: [1, 2, 3])
        lifted.reduce(.other)(&state)
        #expect(state.nums == [1, 2, 3])
    }

    @Test func emptyCollectionIsNoOp() {
        let lifted = bump.liftEach(action: delta, stateCollection: \AppState.nums)
        var state = AppState(nums: [])
        lifted.reduce(.bumpAll(10))(&state)
        #expect(state.nums == [])
    }

    @Test func broadcastsToEveryDictionaryValue() {
        let lifted = bump.liftEach(action: delta, stateDictionary: \AppState.lookup)
        var state = AppState(lookup: ["a": 1, "b": 2])
        lifted.reduce(.bumpAll(5))(&state)
        #expect(state.lookup == ["a": 6, "b": 7])
    }
}
