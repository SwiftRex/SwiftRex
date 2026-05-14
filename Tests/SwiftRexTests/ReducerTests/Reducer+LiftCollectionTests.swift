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

    // MARK: - Dictionary: missing key is a no-op

    func testLiftCollectionDictionaryMissingKeyIsNoOp() {
        let sut = addToInt.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateDictionary: \AppState.lookup
        )
        var state = AppState(lookup: ["a": 1])
        sut.reduce(ElementAction("z", action: 99))(&state)
        XCTAssertNil(state.lookup["z"])
        XCTAssertEqual(state.lookup["a"], 1)
    }

    // MARK: - Custom identifier: missing ID is a no-op

    func testLiftCollectionCustomIdentifierMissingIdIsNoOp() {
        struct Named { var name: String; var score: Int }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [Named(name: "alice", score: 5)])
        sut.reduce(ElementAction("nobody", action: 99))(&state)
        XCTAssertEqual(state.entries[0].score, 5)
    }

    // MARK: - Custom identifier: only the targeted element changes

    func testLiftCollectionCustomIdentifierIsolated() {
        struct Named: Equatable { var name: String; var score: Int }
        struct NamedState { var entries: [Named] = [] }
        let addToScore = Reducer<Int, Named>.reduce { delta, item in item.score += delta }
        let sut = addToScore.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateCollection: \NamedState.entries,
            identifier: \Named.name
        )
        var state = NamedState(entries: [
            Named(name: "alice", score: 0),
            Named(name: "bob", score: 0),
            Named(name: "carol", score: 0)
        ])
        sut.reduce(ElementAction("bob", action: 7))(&state)
        XCTAssertEqual(state.entries[0].score, 0)
        XCTAssertEqual(state.entries[1].score, 7)
        XCTAssertEqual(state.entries[2].score, 0)
    }

    // MARK: - Primitive AffineTraversal: out-of-bounds is a no-op

    func testLiftCollectionPrimitiveOutOfBoundsIsNoOp() {
        let sut = addToInt.liftCollection(
            action: { (ea: ElementAction<Int, Int>?) -> (action: Int, element: AffineTraversal<[Int], Int>)? in
                ea.map { (action: $0.action, element: [Int].ix($0.id)) }
            },
            stateContainer: \Container.nums
        )
        var state = Container(nums: [10, 20, 30])
        sut.reduce(ElementAction(99, action: 5))(&state)
        XCTAssertEqual(state.nums, [10, 20, 30])
    }

    // MARK: - Identifiable: only the targeted element changes

    func testLiftCollectionIdentifiableIsolated() {
        let sut = addToValue.liftCollection(
            action: { (ea: ElementAction<UUID, Int>?) in ea },
            stateCollection: \AppState.items
        )
        var state = AppState(items: [
            Item(id: id1, value: 0),
            Item(id: id2, value: 0)
        ])
        sut.reduce(ElementAction(id2, action: 5))(&state)
        XCTAssertEqual(state.items[0].value, 0)
        XCTAssertEqual(state.items[1].value, 5)
    }

    // MARK: - Lens state container (primitive)

    func testLiftCollectionPrimitiveLensStateContainer() {
        let containerLens = Lens<AppState, [Int]>(
            get: { $0.items.map(\.value) },
            setMut: { appState, ints in
                for (i, v) in ints.enumerated() where i < appState.items.count {
                    appState.items[i].value = v
                }
            }
        )
        let addToInt = Reducer<Int, Int>.reduce { delta, n in n += delta }
        let sut = addToInt.liftCollection(
            action: { (pair: (action: Int, element: AffineTraversal<[Int], Int>)?) in pair },
            stateContainer: containerLens
        )
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        sut.reduce((action: 5, element: [Int].ix(0)))(&state)
        XCTAssertEqual(state.items[0].value, 5)
        XCTAssertEqual(state.items[1].value, 10)
    }

    // MARK: - Identifiable with Lens state container

    func testLiftCollectionIdentifiableLensState() {
        let itemsLens = Lens<AppState, [Item]>(get: { $0.items }, setMut: { $0.items = $1 })
        let sut = addToValue.liftCollection(
            action: { (ea: ElementAction<UUID, Int>?) in ea },
            stateCollection: itemsLens
        )
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        sut.reduce(ElementAction(id1, action: 3))(&state)
        XCTAssertEqual(state.items[0].value, 3)
        XCTAssertEqual(state.items[1].value, 10)
    }

    // MARK: - Custom identifier with closure (genuine closure call)

    func testLiftCollectionCustomIdentifierClosureNotKeyPath() {
        struct Named: Sendable { var tag: String; var count: Int }
        struct NamedState { var entries: [Named] = [] }
        let inc = Reducer<Int, Named>.reduce { delta, item in item.count += delta }
        let sut = inc.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateCollection: \NamedState.entries,
            identifier: { $0.tag }          // genuine closure, not a KeyPath
        )
        var state = NamedState(entries: [Named(tag: "a", count: 0), Named(tag: "b", count: 5)])
        sut.reduce(ElementAction("b", action: 2))(&state)
        XCTAssertEqual(state.entries[0].count, 0)
        XCTAssertEqual(state.entries[1].count, 7)
    }

    // MARK: - Custom identifier with Lens state container

    func testLiftCollectionCustomIdentifierLensState() {
        struct Named: Sendable { var tag: String; var count: Int }
        struct NamedState { var entries: [Named] = [] }
        let inc = Reducer<Int, Named>.reduce { delta, item in item.count += delta }
        let entriesLens = Lens<NamedState, [Named]>(get: { $0.entries }, setMut: { $0.entries = $1 })
        let sut = inc.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateCollection: entriesLens,
            identifier: { $0.tag }
        )
        var state = NamedState(entries: [Named(tag: "x", count: 1)])
        sut.reduce(ElementAction("x", action: 9))(&state)
        XCTAssertEqual(state.entries[0].count, 10)
    }

    // MARK: - Dictionary with Lens state container

    func testLiftCollectionDictionaryLensState() {
        let lookupLens = Lens<AppState, [String: Int]>(get: { $0.lookup }, setMut: { $0.lookup = $1 })
        let sut = addToInt.liftCollection(
            action: { (ea: ElementAction<String, Int>?) in ea },
            stateDictionary: lookupLens
        )
        var state = AppState(items: [], lookup: ["score": 10])
        sut.reduce(ElementAction("score", action: 5))(&state)
        XCTAssertEqual(state.lookup["score"], 15)
    }
}
