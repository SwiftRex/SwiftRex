import XCTest
import CoreFP
@testable import SwiftRex

final class ReducerLiftCollectionTests: XCTestCase {
    // MARK: - Helpers

    private struct Item: Identifiable {
        var id: Int
        var value: Int
    }

    private struct AppState {
        var items: [Item] = []
        var lookup: [String: Int] = [:]
    }

    private struct Container {
        var nums: [Int] = []
    }

    private struct GACollection {
        var update: CollectionAction<AppState, Item, Int>?
    }

    private let addToValue = Reducer<Int, Item>.reduce { delta, item in item.value += delta }
    private let addToInt = Reducer<Int, Int>.reduce { delta, n in n += delta }

    // MARK: - CollectionAction (KeyPath)

    func testLiftCollectionCollectionActionKeyPath() {
        let sut = addToValue.liftCollection(action: \GACollection.update)
        var state = AppState(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        sut.reduce(GACollection(update: CollectionAction(\AppState.items, id: 1, action: 5)), &state)
        XCTAssertEqual(state.items[0].value, 5)
        XCTAssertEqual(state.items[1].value, 10)
    }

    func testLiftCollectionCollectionActionSkipsWhenNil() {
        let sut = addToValue.liftCollection(action: \GACollection.update)
        var state = AppState(items: [Item(id: 1, value: 0)])
        sut.reduce(GACollection(update: nil), &state)
        XCTAssertEqual(state.items[0].value, 0)
    }

    // MARK: - CollectionAction (closure)

    func testLiftCollectionCollectionActionClosure() {
        let sut = addToValue.liftCollection(action: { (ga: GACollection) in ga.update })
        var state = AppState(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        sut.reduce(GACollection(update: CollectionAction(\AppState.items, id: 2, action: 3)), &state)
        XCTAssertEqual(state.items[0].value, 0)
        XCTAssertEqual(state.items[1].value, 13)
    }

    // MARK: - Identifiable (closure)

    func testLiftCollectionIdentifiableClosure() {
        let sut = addToValue.liftCollection(
            action: { (p: (id: Int, action: Int)?) in p },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        sut.reduce((id: 1, action: 3), &state)
        XCTAssertEqual(state.items[0].value, 3)
        XCTAssertEqual(state.items[1].value, 10)
    }

    func testLiftCollectionIdentifiableClosureSkipsWhenNil() {
        let sut = addToValue.liftCollection(
            action: { (p: (id: Int, action: Int)?) in p },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [Item(id: 1, value: 5)])
        sut.reduce((id: Int, action: Int)?.none, &state)
        XCTAssertEqual(state.items[0].value, 5)
    }

    // MARK: - Identifiable (KeyPath)

    func testLiftCollectionIdentifiableKeyPath() {
        struct GAId { var update: (id: Int, action: Int)? }
        let sut = addToValue.liftCollection(action: \GAId.update, stateCollection: \AppState.items)
        var state = AppState(items: [Item(id: 1, value: 0)])
        sut.reduce(GAId(update: (id: 1, action: 7)), &state)
        XCTAssertEqual(state.items[0].value, 7)
        sut.reduce(GAId(update: nil), &state)
        XCTAssertEqual(state.items[0].value, 7)
    }

    // MARK: - Custom Hashable identifier (closure)

    func testLiftCollectionCustomIdentifierClosure() {
        struct Named { var name: String; var score: Int }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: { (p: (id: String, action: Int)?) in p },
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [Named(name: "alice", score: 0), Named(name: "bob", score: 5)])
        sut.reduce((id: "alice", action: 3), &state)
        XCTAssertEqual(state.entries[0].score, 3)
        XCTAssertEqual(state.entries[1].score, 5)
    }

    // MARK: - Custom Hashable identifier (KeyPath)

    func testLiftCollectionCustomIdentifierKeyPath() {
        struct Named { var name: String; var score: Int }
        struct GACustom { var update: (id: String, action: Int)? }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: \GACustom.update,
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [Named(name: "alice", score: 0)])
        sut.reduce(GACustom(update: (id: "alice", action: 4)), &state)
        XCTAssertEqual(state.entries[0].score, 4)
    }

    // MARK: - Index-based (closure)

    func testLiftCollectionIndexClosure() {
        typealias IndexAction = (index: Int, action: Int)?
        let sut: Reducer<IndexAction, Container> = addToInt.liftCollection(
            action: { (p: IndexAction) in p },
            stateCollection: \Container.nums
        )
        var state = Container(nums: [10, 20, 30])
        sut.reduce((index: 1, action: 5), &state)
        XCTAssertEqual(state.nums, [10, 25, 30])
        sut.reduce(IndexAction.none, &state)
        XCTAssertEqual(state.nums, [10, 25, 30])
    }

    // MARK: - Index-based (KeyPath)

    func testLiftCollectionIndexKeyPath() {
        struct GAIdx { var update: (index: Int, action: Int)? }
        let sut = addToInt.liftCollection(action: \GAIdx.update, stateCollection: \Container.nums)
        var state = Container(nums: [0, 100])
        sut.reduce(GAIdx(update: (index: 0, action: 10)), &state)
        XCTAssertEqual(state.nums, [10, 100])
        sut.reduce(GAIdx(update: nil), &state)
        XCTAssertEqual(state.nums, [10, 100])
    }

    // MARK: - Primitive two-sided (AffineTraversal)

    func testLiftCollectionPrimitive() {
        typealias IndexAction = (index: Int, action: Int)?
        let sut = addToInt.liftCollection(
            action: { (p: IndexAction) -> (action: Int, element: AffineTraversal<[Int], Int>)? in
                p.map { (action: $0.action, element: [Int].ix($0.index)) }
            },
            stateContainer: \Container.nums
        )
        var state = Container(nums: [10, 20, 30])
        sut.reduce((index: 2, action: 5), &state)
        XCTAssertEqual(state.nums, [10, 20, 35])
        sut.reduce(IndexAction.none, &state)
        XCTAssertEqual(state.nums, [10, 20, 35])
    }

    // MARK: - Dictionary key-based (closure)

    func testLiftCollectionDictionaryClosure() {
        typealias KeyAction = (key: String, action: Int)?
        let sut: Reducer<KeyAction, AppState> = addToInt.liftCollection(
            action: { (p: KeyAction) in p },
            stateDictionary: \AppState.lookup
        )
        var state = AppState(lookup: ["a": 0, "b": 10])
        sut.reduce((key: "a", action: 3), &state)
        XCTAssertEqual(state.lookup["a"], 3)
        XCTAssertEqual(state.lookup["b"], 10)
    }

    // MARK: - Dictionary key-based (KeyPath)

    func testLiftCollectionDictionaryKeyPath() {
        struct GADict { var update: (key: String, action: Int)? }
        let sut = addToInt.liftCollection(action: \GADict.update, stateDictionary: \AppState.lookup)
        var state = AppState(lookup: ["x": 5])
        sut.reduce(GADict(update: (key: "x", action: 2)), &state)
        XCTAssertEqual(state.lookup["x"], 7)
        sut.reduce(GADict(update: nil), &state)
        XCTAssertEqual(state.lookup["x"], 7)
    }
}
