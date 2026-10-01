// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

@Suite
struct ReducerLiftEachTests {
    private struct AppState: Equatable, Sendable {
        var nums: [Int] = []
        var lookup: [String: Int] = [:]
    }

    private enum AppAction: Sendable {
        case bumpAll(Int)
        case other
    }

    private let bump = Reducer<Int, Int>.reduce { delta, n in n += delta }

    private static func delta(_ action: AppAction) -> Int? {
        if case let .bumpAll(d) = action { d } else { nil }
    }

    // A reducer emits nothing, so the broadcast lane's per-element embed is never used.
    private static func embed<ID>(_: ID, _ d: Int) -> AppAction { .bumpAll(d) }

    @Test func broadcastsToEveryArrayElement() {
        let lifted = bump.liftEach(.action(broadcast: Self.delta, embed: Self.embed).state(indexed: \AppState.nums))
        var state = AppState(nums: [1, 2, 3])
        lifted.reduce(.bumpAll(10))(&state)
        #expect(state.nums == [11, 12, 13])
    }

    @Test func ignoresUnmatchedAction() {
        let lifted = bump.liftEach(.action(broadcast: Self.delta, embed: Self.embed).state(indexed: \AppState.nums))
        var state = AppState(nums: [1, 2, 3])
        lifted.reduce(.other)(&state)
        #expect(state.nums == [1, 2, 3])
    }

    @Test func emptyCollectionIsNoOp() {
        let lifted = bump.liftEach(.action(broadcast: Self.delta, embed: Self.embed).state(indexed: \AppState.nums))
        var state = AppState(nums: [])
        lifted.reduce(.bumpAll(10))(&state)
        #expect(state.nums == [])
    }

    @Test func broadcastsToEveryDictionaryValue() {
        let lifted = bump.liftEach(.action(broadcast: Self.delta, embed: Self.embed).state(dictionary: \AppState.lookup))
        var state = AppState(lookup: ["a": 1, "b": 2])
        lifted.reduce(.bumpAll(5))(&state)
        #expect(state.lookup == ["a": 6, "b": 7])
    }
}
