// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
@testable import SwiftRex
import Testing

@Suite
struct ReducerLiftCollectionTests {
    // MARK: - Domain

    private struct Item: Identifiable, Sendable {
        let id: UUID
        var value: Int
    }

    private struct Named: Equatable, Sendable {
        var name: String
        var score: Int
    }

    private struct AppState: Sendable {
        var items: [Item] = []
        var entries: [Named] = []
        var nums: [Int] = []
        var lookup: [String: Int] = [:]
    }

    private enum AppAction: Sendable {
        case item(ElementAction<UUID, Int>)
        case named(ElementAction<String, Int>)
        case num(ElementAction<Int, Int>)
        case keyed(ElementAction<String, Int>)
        case unrelated
    }

    private static let item = Prism<AppAction, ElementAction<UUID, Int>>(
        preview: { if case let .item(ea) = $0 { ea } else { nil } },
        review: AppAction.item
    )
    private static let named = Prism<AppAction, ElementAction<String, Int>>(
        preview: { if case let .named(ea) = $0 { ea } else { nil } },
        review: AppAction.named
    )
    private static let num = Prism<AppAction, ElementAction<Int, Int>>(
        preview: { if case let .num(ea) = $0 { ea } else { nil } },
        review: AppAction.num
    )
    private static let keyed = Prism<AppAction, ElementAction<String, Int>>(
        preview: { if case let .keyed(ea) = $0 { ea } else { nil } },
        review: AppAction.keyed
    )

    private let id1 = UUID()
    private let id2 = UUID()

    private let addToValue = Reducer<Int, Item>.reduce { delta, item in item.value += delta }
    private let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
    private let addToInt = Reducer<Int, Int>.reduce { delta, n in n += delta }

    // MARK: - Identifiable

    @Test func identifiableMutatesOnlyTheTarget() {
        let sut = addToValue.liftCollection(.action(Self.item).state(\AppState.items))
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        sut.reduce(.item(ElementAction(id1, action: 3)))(&state)
        #expect(state.items.map(\.value) == [3, 10])
    }

    @Test func unmatchedActionIsNoOp() {
        let sut = addToValue.liftCollection(.action(Self.item).state(\AppState.items))
        var state = AppState(items: [Item(id: id1, value: 5)])
        sut.reduce(.unrelated)(&state)
        #expect(state.items[0].value == 5)
    }

    @Test func missingIdIsNoOp() {
        let sut = addToValue.liftCollection(.action(Self.item).state(\AppState.items))
        var state = AppState(items: [Item(id: id1, value: 5)])
        sut.reduce(.item(ElementAction(id2, action: 99)))(&state)
        #expect(state.items[0].value == 5)
    }

    @Test func identifiableThroughLens() {
        let itemsLens = Lens<AppState, [Item]>(get: { $0.items }, setMut: { $0.items = $1 })
        let sut = addToValue.liftCollection(.action(Self.item).state(itemsLens))
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        sut.reduce(.item(ElementAction(id1, action: 3)))(&state)
        #expect(state.items.map(\.value) == [3, 10])
    }

    // MARK: - Custom identifier

    @Test func customIdentifierMutatesOnlyTheTarget() {
        let sut = addToScore.liftCollection(.action(Self.named).state(\AppState.entries, id: \.name))
        var state = AppState(entries: [
            Named(name: "alice", score: 0),
            Named(name: "bob", score: 0),
            Named(name: "carol", score: 0)
        ])
        sut.reduce(.named(ElementAction("bob", action: 7)))(&state)
        #expect(state.entries.map(\.score) == [0, 7, 0])
    }

    @Test func customIdentifierMissingIdIsNoOp() {
        let sut = addToScore.liftCollection(.action(Self.named).state(\AppState.entries, id: \.name))
        var state = AppState(entries: [Named(name: "alice", score: 5)])
        sut.reduce(.named(ElementAction("nobody", action: 99)))(&state)
        #expect(state.entries[0].score == 5)
    }

    @Test func customIdentifierThroughLens() {
        let entriesLens = Lens<AppState, [Named]>(get: { $0.entries }, setMut: { $0.entries = $1 })
        let sut = addToScore.liftCollection(.action(Self.named).state(entriesLens, id: \.name))
        var state = AppState(entries: [Named(name: "x", score: 1)])
        sut.reduce(.named(ElementAction("x", action: 9)))(&state)
        #expect(state.entries[0].score == 10)
    }

    // MARK: - Index

    @Test func indexMutatesThePosition() {
        let sut = addToInt.liftCollection(.action(Self.num).state(indexed: \AppState.nums))
        var state = AppState(nums: [10, 20, 30])
        sut.reduce(.num(ElementAction(1, action: 5)))(&state)
        #expect(state.nums == [10, 25, 30])
    }

    @Test func indexOutOfBoundsIsNoOp() {
        let sut = addToInt.liftCollection(.action(Self.num).state(indexed: \AppState.nums))
        var state = AppState(nums: [10, 20, 30])
        sut.reduce(.num(ElementAction(99, action: 5)))(&state)
        #expect(state.nums == [10, 20, 30])
    }

    // MARK: - Dictionary

    @Test func dictionaryMutatesTheKey() {
        let sut = addToInt.liftCollection(.action(Self.keyed).state(dictionary: \AppState.lookup))
        var state = AppState(lookup: ["a": 0, "b": 10])
        sut.reduce(.keyed(ElementAction("a", action: 3)))(&state)
        #expect(state.lookup == ["a": 3, "b": 10])
    }

    @Test func dictionaryMissingKeyIsNoOp() {
        let sut = addToInt.liftCollection(.action(Self.keyed).state(dictionary: \AppState.lookup))
        var state = AppState(lookup: ["a": 1])
        sut.reduce(.keyed(ElementAction("z", action: 99)))(&state)
        #expect(state.lookup == ["a": 1])
    }

    @Test func dictionaryThroughLens() {
        let lookupLens = Lens<AppState, [String: Int]>(get: { $0.lookup }, setMut: { $0.lookup = $1 })
        let sut = addToInt.liftCollection(.action(Self.keyed).state(dictionary: lookupLens))
        var state = AppState(lookup: ["score": 10])
        sut.reduce(.keyed(ElementAction("score", action: 5)))(&state)
        #expect(state.lookup["score"] == 15)
    }
}
