import XCTest
import CoreFP
@testable import SwiftRex

final class CollectionActionTests: XCTestCase {
    private struct Item: Identifiable {
        var id: Int
        var value: Int
    }

    private struct AppRoot {
        var items: [Item] = []
        var lookup: [String: Int] = [:]
    }

    // MARK: - Primary init

    func testPrimaryInitStoresTraversalAndAction() {
        let traversal = AffineTraversal<AppRoot, Item>(
            preview: { $0.items.first },
            set: { root, item in
                var copy = root
                if !copy.items.isEmpty { copy.items[0] = item }
                return copy
            }
        )
        let sut = CollectionAction(traversal, action: 42)
        XCTAssertEqual(sut.action, 42)
        let root = AppRoot(items: [Item(id: 1, value: 0)])
        XCTAssertEqual(sut.elementInRoot.preview(root)?.id, 1)
    }

    // MARK: - AffineTraversal convenience

    func testConvenienceInitWithElementTraversal() {
        let sut = CollectionAction(\AppRoot.items, element: [Item].ix(0), action: 7)
        var root = AppRoot(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        XCTAssertEqual(sut.elementInRoot.preview(root)?.id, 1)
        root = sut.elementInRoot.set(root, Item(id: 1, value: 99))
        XCTAssertEqual(root.items[0].value, 99)
        XCTAssertEqual(root.items[1].value, 10)
    }

    // MARK: - Identifiable

    func testIdentifiableInitLocatesElementById() {
        let sut = CollectionAction(\AppRoot.items, id: 2, action: 5)
        let root = AppRoot(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        XCTAssertEqual(sut.elementInRoot.preview(root)?.id, 2)
        XCTAssertEqual(sut.action, 5)
    }

    func testIdentifiableInitReturnsNilForMissingId() {
        let sut = CollectionAction(\AppRoot.items, id: 99, action: 0)
        let root = AppRoot(items: [Item(id: 1, value: 0)])
        XCTAssertNil(sut.elementInRoot.preview(root))
    }

    func testIdentifiableInitSetsElement() {
        let sut = CollectionAction(\AppRoot.items, id: 1, action: 0)
        var root = AppRoot(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        root = sut.elementInRoot.set(root, Item(id: 1, value: 42))
        XCTAssertEqual(root.items[0].value, 42)
        XCTAssertEqual(root.items[1].value, 10)
    }

    // MARK: - Custom Hashable identifier

    func testCustomIdentifierInit() {
        struct Named { var name: String; var score: Int }
        struct NamedRoot { var entries: [Named] }
        let sut = CollectionAction(\NamedRoot.entries, id: "alice", identifier: \Named.name, action: 3)
        let root = NamedRoot(entries: [Named(name: "alice", score: 0), Named(name: "bob", score: 5)])
        XCTAssertEqual(sut.elementInRoot.preview(root)?.name, "alice")
        XCTAssertEqual(sut.action, 3)
    }

    func testCustomIdentifierInitSetsElement() {
        struct Named { var name: String; var score: Int }
        struct NamedRoot { var entries: [Named] }
        let sut = CollectionAction(\NamedRoot.entries, id: "bob", identifier: \Named.name, action: 0)
        var root = NamedRoot(entries: [Named(name: "alice", score: 0), Named(name: "bob", score: 5)])
        root = sut.elementInRoot.set(root, Named(name: "bob", score: 99))
        XCTAssertEqual(root.entries[0].score, 0)
        XCTAssertEqual(root.entries[1].score, 99)
    }

    // MARK: - Index-based

    func testIndexInitLocatesElement() {
        let sut = CollectionAction(\AppRoot.items, index: 1, action: 0)
        let root = AppRoot(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        XCTAssertEqual(sut.elementInRoot.preview(root)?.id, 2)
    }

    func testIndexInitSetsElement() {
        let sut = CollectionAction(\AppRoot.items, index: 0, action: 0)
        var root = AppRoot(items: [Item(id: 1, value: 0), Item(id: 2, value: 10)])
        root = sut.elementInRoot.set(root, Item(id: 1, value: 55))
        XCTAssertEqual(root.items[0].value, 55)
        XCTAssertEqual(root.items[1].value, 10)
    }

    // MARK: - Dictionary key-based

    func testDictionaryKeyInitLocatesEntry() {
        let sut = CollectionAction(\AppRoot.lookup, key: "alpha", action: 0)
        let root = AppRoot(lookup: ["alpha": 42, "beta": 7])
        XCTAssertEqual(sut.elementInRoot.preview(root), 42)
    }

    func testDictionaryKeyInitReturnsNilForMissingKey() {
        let sut = CollectionAction(\AppRoot.lookup, key: "missing", action: 0)
        let root = AppRoot(lookup: ["alpha": 1])
        XCTAssertNil(sut.elementInRoot.preview(root))
    }

    func testDictionaryKeyInitSetsEntry() {
        let sut = CollectionAction(\AppRoot.lookup, key: "alpha", action: 0)
        var root = AppRoot(lookup: ["alpha": 0, "beta": 7])
        root = sut.elementInRoot.set(root, 99)
        XCTAssertEqual(root.lookup["alpha"], 99)
        XCTAssertEqual(root.lookup["beta"], 7)
    }
}
