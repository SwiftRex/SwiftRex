import XCTest
import CoreFP
@testable import SwiftRex

final class ReducerLiftCollectionTests: XCTestCase {
    // MARK: - Helpers

    private struct Item: Identifiable {
        let id: UUID
        var value: Int
    }

    private struct AppState {
        var items: [Item] = []
        var lookup: [String: Int] = [:]
    }

    private struct Container {
        var nums: [Int] = []
    }

    private let id1 = UUID()
    private let id2 = UUID()

    private let addToValue = Reducer<Int, Item>.reduce { delta, item in item.value += delta }
    private let addToInt = Reducer<Int, Int>.reduce { delta, n in n += delta }

    // MARK: - Identifiable (closure)

    func testLiftCollectionIdentifiableClosure() {
        let sut = addToValue.liftCollection(
            action: { (ea: ElementAction<UUID, Int>?) in ea },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        sut.reduce(ElementAction(id1, action: 3))(&state)
        XCTAssertEqual(state.items[0].value, 3)
        XCTAssertEqual(state.items[1].value, 10)
    }

    func testLiftCollectionIdentifiableClosureSkipsWhenNil() {
        let sut = addToValue.liftCollection(
            action: { (ea: ElementAction<UUID, Int>?) in ea },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [Item(id: id1, value: 5)])
        sut.reduce(ElementAction<UUID, Int>?.none)(&state)
        XCTAssertEqual(state.items[0].value, 5)
    }

    func testLiftCollectionIdentifiableClosureSkipsWhenIdMissing() {
        let sut = addToValue.liftCollection(
            action: { (ea: ElementAction<UUID, Int>?) in ea },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [Item(id: id1, value: 5)])
        sut.reduce(ElementAction(id2, action: 99))(&state)
        XCTAssertEqual(state.items[0].value, 5)
    }

    // MARK: - Identifiable (KeyPath)

    func testLiftCollectionIdentifiableKeyPath() {
        struct GAId { var update: ElementAction<UUID, Int>? }
        let sut = addToValue.liftCollection(action: \GAId.update, stateCollection: \AppState.items)
        var state = AppState(items: [Item(id: id1, value: 0)])
        sut.reduce(GAId(update: ElementAction(id1, action: 7)))(&state)
        XCTAssertEqual(state.items[0].value, 7)
        sut.reduce(GAId(update: nil))(&state)
        XCTAssertEqual(state.items[0].value, 7)
    }

    // MARK: - Custom Hashable identifier (closure)

    func testLiftCollectionCustomIdentifierClosure() {
        struct Named { var name: String; var score: Int }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [Named(name: "alice", score: 0), Named(name: "bob", score: 5)])
        sut.reduce(ElementAction("alice", action: 3))(&state)
        XCTAssertEqual(state.entries[0].score, 3)
        XCTAssertEqual(state.entries[1].score, 5)
    }

    // MARK: - Custom Hashable identifier (KeyPath)

    func testLiftCollectionCustomIdentifierKeyPath() {
        struct Named { var name: String; var score: Int }
        struct GACustom { var update: ElementAction<String, Int>? }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: \GACustom.update,
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [Named(name: "alice", score: 0)])
        sut.reduce(GACustom(update: ElementAction("alice", action: 4)))(&state)
        XCTAssertEqual(state.entries[0].score, 4)
    }

    // MARK: - Index-based (primitive AffineTraversal)

    func testLiftCollectionIndexViaPrimitive() {
        let sut = addToInt.liftCollection(
            action: { (ea: ElementAction<Int, Int>?) -> (action: Int, element: AffineTraversal<[Int], Int>)? in
                ea.map { (action: $0.action, element: [Int].ix($0.id)) }
            },
            stateContainer: \Container.nums
        )
        var state = Container(nums: [10, 20, 30])
        sut.reduce(ElementAction(1, action: 5))(&state)
        XCTAssertEqual(state.nums, [10, 25, 30])
        sut.reduce(ElementAction<Int, Int>?.none)(&state)
        XCTAssertEqual(state.nums, [10, 25, 30])
    }

    // MARK: - Dictionary key-based (closure)

    func testLiftCollectionDictionaryClosure() {
        let sut = addToInt.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateDictionary: \AppState.lookup
        )
        var state = AppState(lookup: ["a": 0, "b": 10])
        sut.reduce(ElementAction("a", action: 3))(&state)
        XCTAssertEqual(state.lookup["a"], 3)
        XCTAssertEqual(state.lookup["b"], 10)
    }

    // MARK: - Dictionary key-based (KeyPath)

    func testLiftCollectionDictionaryKeyPath() {
        struct GADict { var update: ElementAction<String, Int>? }
        let sut = addToInt.liftCollection(action: \GADict.update, stateDictionary: \AppState.lookup)
        var state = AppState(lookup: ["x": 5])
        sut.reduce(GADict(update: ElementAction("x", action: 2)))(&state)
        XCTAssertEqual(state.lookup["x"], 7)
        sut.reduce(GADict(update: nil))(&state)
        XCTAssertEqual(state.lookup["x"], 7)
    }
}
