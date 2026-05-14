import Testing
import CoreFP
@testable import SwiftRex

// MARK: - Helpers

private struct AppAction: Sendable { var counter: Int?; var other: String? }
private struct AppState: Sendable { var count: Int = 0; var label: String = "" }

@MainActor
private func appStore(count: Int = 0, label: String = "") -> Store<AppAction, AppState, Void> {
    Store(
        initial: AppState(count: count, label: label),
        behavior: Behavior<AppAction, AppState, Void>.handle { action, _ in
            guard let n = action.action.counter else { return .doNothing }
            return .reduce { $0.count += n }
        },
        environment: ()
    )
}

// MARK: - Basic projection

@Suite("StoreProjection")
@MainActor
struct StoreProjectionTests {
    @Test func stateIsMappedFromGlobal() {
        let store = appStore(count: 42)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        #expect(proj.state == 42)
    }

    @Test func stateReflectsLiveStoreChanges() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        store.dispatch(AppAction(counter: 5, other: nil))
        #expect(proj.state == 5)
    }

    @Test func dispatchIsForwardedWithActionMapping() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        proj.dispatch(3)
        #expect(store.state.count == 3)
    }

    @Test func observeForwardsToUnderlyingStore() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        let seen = LockProtected([Int]())
        _ = proj.observe(willChange: {}, didChange: { seen.mutate { $0.append(proj.state) } })
        store.dispatch(AppAction(counter: 7, other: nil))
        #expect(seen.value == [7])
    }
}

// MARK: - Collection element projection (Identifiable)

private struct Item: Identifiable, Sendable { let id: Int; var value: String }
private struct ListState: Sendable { var items: [Item] = [] }
private enum ListAction: Sendable { case update(id: Int, value: String) }

@Suite("StoreProjection collection element (Identifiable)")
@MainActor
struct StoreProjectionIdentifiableTests {
    private func listStore(items: [Item]) -> Store<ElementAction<Int, String>, ListState, Void> {
        Store(
            initial: ListState(items: items),
            behavior: Behavior<ElementAction<Int, String>, ListState, Void>.handle { action, _ in
                .reduce { state in
                    guard let idx = state.items.firstIndex(where: { $0.id == action.action.id }) else { return }
                    state.items[idx].value = action.action.action
                }
            },
            environment: ()
        )
    }

    @Test func stateIsElementWhenPresent() {
        let store = listStore(items: [Item(id: 1, value: "a"), Item(id: 2, value: "b")])
        let proj = store.projection(
            element: 2,
            actionReview: { $0 },
            stateCollection: \.items
        )
        #expect(proj.state?.id == 2)
        #expect(proj.state?.value == "b")
    }

    @Test func stateIsNilWhenElementAbsent() {
        let store = listStore(items: [Item(id: 1, value: "a")])
        let proj = store.projection(
            element: 99,
            actionReview: { $0 },
            stateCollection: \.items
        )
        #expect(proj.state == nil)
    }

    @Test func dispatchWrapsActionInElementAction() {
        let store = listStore(items: [Item(id: 1, value: "old")])
        let proj = store.projection(
            element: 1,
            actionReview: { $0 },
            stateCollection: \.items
        )
        proj.dispatch("new")
        #expect(store.state.items.first?.value == "new")
    }
}

// MARK: - Collection element projection (custom identifier closure)

private struct Tagged: Sendable { let tag: String; var score: Int }
private struct TaggedState: Sendable { var entries: [Tagged] = [] }

@Suite("StoreProjection collection element (custom identifier closure)")
@MainActor
struct StoreProjectionCustomIdentifierTests {
    private func taggedStore(entries: [Tagged]) -> Store<ElementAction<String, Int>, TaggedState, Void> {
        Store(
            initial: TaggedState(entries: entries),
            behavior: Behavior<ElementAction<String, Int>, TaggedState, Void>.handle { action, _ in
                .reduce { state in
                    guard let idx = state.entries.firstIndex(where: { $0.tag == action.action.id }) else { return }
                    state.entries[idx].score = action.action.action
                }
            },
            environment: ()
        )
    }

    @Test func stateIsElementWhenPresent() {
        let store = taggedStore(entries: [Tagged(tag: "a", score: 1), Tagged(tag: "b", score: 2)])
        let proj = store.projection(
            element: "b",
            actionReview: { $0 },
            stateCollection: \.entries,
            identifier: { $0.tag }
        )
        #expect(proj.state?.score == 2)
    }

    @Test func stateIsNilWhenElementAbsent() {
        let store = taggedStore(entries: [Tagged(tag: "a", score: 1)])
        let proj = store.projection(
            element: "missing",
            actionReview: { $0 },
            stateCollection: \.entries,
            identifier: { $0.tag }
        )
        #expect(proj.state == nil)
    }

    @Test func dispatchUpdatesCorrectElement() {
        let store = taggedStore(entries: [Tagged(tag: "x", score: 0), Tagged(tag: "y", score: 5)])
        let proj = store.projection(
            element: "x",
            actionReview: { $0 },
            stateCollection: \.entries,
            identifier: { $0.tag }
        )
        proj.dispatch(99)
        #expect(store.state.entries[0].score == 99)
        #expect(store.state.entries[1].score == 5)
    }
}

// MARK: - Dictionary projection

@Suite("StoreProjection dictionary key")
@MainActor
struct StoreProjectionDictionaryTests {
    private struct DictState: Sendable { var map: [String: Int] = [:] }

    private func dictStore(map: [String: Int]) -> Store<ElementAction<String, Int>, DictState, Void> {
        Store(
            initial: DictState(map: map),
            behavior: Behavior<ElementAction<String, Int>, DictState, Void>.handle { action, _ in
                .reduce { state in state.map[action.action.id] = action.action.action }
            },
            environment: ()
        )
    }

    @Test func stateIsValueWhenKeyPresent() {
        let store = dictStore(map: ["x": 10])
        let proj = store.projection(key: "x", actionReview: { $0 }, stateDictionary: \.map)
        #expect(proj.state == 10)
    }

    @Test func stateIsNilWhenKeyAbsent() {
        let store = dictStore(map: [:])
        let proj = store.projection(key: "missing", actionReview: { $0 }, stateDictionary: \.map)
        #expect(proj.state == nil)
    }

    @Test func dispatchWritesNewValue() {
        let store = dictStore(map: ["k": 0])
        let proj = store.projection(key: "k", actionReview: { $0 }, stateDictionary: \.map)
        proj.dispatch(99)
        #expect(store.state.map["k"] == 99)
    }
}
