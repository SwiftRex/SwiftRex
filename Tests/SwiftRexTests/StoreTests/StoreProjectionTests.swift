// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
@testable import SwiftRex
import Testing

// MARK: - Helpers

private struct AppAction: Sendable { var counter: Int?; var other: String? }
private struct AppState: Sendable { var count: Int = 0; var label: String = "" }

@MainActor
private func appStore(count: Int = 0, label: String = "") -> Store<AppAction, AppState, Void> {
    Store(
        initial: AppState(count: count, label: label),
        behavior: Behavior<AppAction, AppState, Void>.handle { action, _ in
            guard let n = action.counter else { return .doNothing }
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
        #expect(proj.currentState == 42)
    }

    @Test func stateReflectsLiveStoreChanges() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        store.dispatch(AppAction(counter: 5, other: nil))
        #expect(proj.currentState == 5)
    }

    @Test func dispatchIsForwardedWithActionMapping() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        proj.dispatch(3)
        #expect(store.currentState.count == 3)
    }

    @Test func streamMapsTheUnderlyingStream() {
        let store = appStore(count: 0)
        let proj = store.projection(
            action: { AppAction(counter: $0, other: nil) },
            state: { $0.count }
        )
        let seen = LockProtected([Int]())
        let token = proj.stateStream.subscribe { value in seen.mutate { $0.append(value) } }.token
        store.dispatch(AppAction(counter: 7, other: nil))
        #expect(seen.value == [7])
        withExtendedLifetime(token) {}
    }
}

// MARK: - Collection element focus (Identifiable)

private struct Item: Identifiable, Sendable { let id: Int; var value: String }
private struct ListState: Sendable { var items: [Item] = [] }
private enum ListAction: Sendable { case update(id: Int, value: String) }

// The stores below take the element action itself as their global action, so the action lane is the identity prism.
private func identity<A>() -> Prism<A, A> { Prism(preview: { $0 }, review: { $0 }) }

@Suite("StoreCollectionFocus (Identifiable)")
@MainActor
struct StoreProjectionIdentifiableTests {
    private func listStore(items: [Item]) -> Store<ElementAction<Int, String>, ListState, Void> {
        Store(
            initial: ListState(items: items),
            behavior: Behavior<ElementAction<Int, String>, ListState, Void>.handle { action, _ in
                .reduce { state in
                    guard let idx = state.items.firstIndex(where: { $0.id == action.id }) else { return }
                    state.items[idx].value = action.action
                }
            },
            environment: ()
        )
    }

    @Test func stateIsElementWhenPresent() {
        let store = listStore(items: [Item(id: 1, value: "a"), Item(id: 2, value: "b")])
        let proj = store.projection(.action(identity()).state(\ListState.items), element: 2)
        #expect(proj.currentState?.id == 2)
        #expect(proj.currentState?.value == "b")
    }

    @Test func stateIsNilWhenElementAbsent() {
        let store = listStore(items: [Item(id: 1, value: "a")])
        let proj = store.projection(.action(identity()).state(\ListState.items), element: 99)
        #expect(proj.currentState == nil)
    }

    @Test func dispatchWrapsActionInElementAction() {
        let store = listStore(items: [Item(id: 1, value: "old")])
        let proj = store.projection(.action(identity()).state(\ListState.items), element: 1)
        proj.dispatch("new")
        #expect(store.currentState.items.first?.value == "new")
    }
}

// MARK: - Collection element focus (custom identifier)

private struct Tagged: Sendable { let tag: String; var score: Int }
private struct TaggedState: Sendable { var entries: [Tagged] = [] }

@Suite("StoreCollectionFocus (custom identifier)")
@MainActor
struct StoreProjectionCustomIdentifierTests {
    private func taggedStore(entries: [Tagged]) -> Store<ElementAction<String, Int>, TaggedState, Void> {
        Store(
            initial: TaggedState(entries: entries),
            behavior: Behavior<ElementAction<String, Int>, TaggedState, Void>.handle { action, _ in
                .reduce { state in
                    guard let idx = state.entries.firstIndex(where: { $0.tag == action.id }) else { return }
                    state.entries[idx].score = action.action
                }
            },
            environment: ()
        )
    }

    @Test func stateIsElementWhenPresent() {
        let store = taggedStore(entries: [Tagged(tag: "a", score: 1), Tagged(tag: "b", score: 2)])
        let proj = store.projection(.action(identity()).state(\TaggedState.entries, id: \.tag), element: "b")
        #expect(proj.currentState?.score == 2)
    }

    @Test func stateIsNilWhenElementAbsent() {
        let store = taggedStore(entries: [Tagged(tag: "a", score: 1)])
        let proj = store.projection(.action(identity()).state(\TaggedState.entries, id: \.tag), element: "missing")
        #expect(proj.currentState == nil)
    }

    @Test func dispatchUpdatesCorrectElement() {
        let store = taggedStore(entries: [Tagged(tag: "x", score: 0), Tagged(tag: "y", score: 5)])
        let proj = store.projection(.action(identity()).state(\TaggedState.entries, id: \.tag), element: "x")
        proj.dispatch(99)
        #expect(store.currentState.entries[0].score == 99)
        #expect(store.currentState.entries[1].score == 5)
    }
}

// MARK: - Dictionary element focus

@Suite("StoreCollectionFocus (dictionary key)")
@MainActor
struct StoreProjectionDictionaryTests {
    private struct DictState: Sendable { var map: [String: Int] = [:] }

    private func dictStore(map: [String: Int]) -> Store<ElementAction<String, Int>, DictState, Void> {
        Store(
            initial: DictState(map: map),
            behavior: Behavior<ElementAction<String, Int>, DictState, Void>.handle { action, _ in
                .reduce { state in state.map[action.id] = action.action }
            },
            environment: ()
        )
    }

    @Test func stateIsValueWhenKeyPresent() {
        let store = dictStore(map: ["x": 10])
        let proj = store.projection(.action(identity()).state(dictionary: \DictState.map), element: "x")
        #expect(proj.currentState == 10)
    }

    @Test func stateIsNilWhenKeyAbsent() {
        let store = dictStore(map: [:])
        let proj = store.projection(.action(identity()).state(dictionary: \DictState.map), element: "missing")
        #expect(proj.currentState == nil)
    }

    @Test func dispatchWritesNewValue() {
        let store = dictStore(map: ["k": 0])
        let proj = store.projection(.action(identity()).state(dictionary: \DictState.map), element: "k")
        proj.dispatch(99)
        #expect(store.currentState.map["k"] == 99)
    }
}

// MARK: - Environment-aware projection

@Suite("StoreProjection environment-aware")
@MainActor
struct StoreProjectionEnvironmentTests {
    private struct Env: Sendable { var scale: Int; var prefix: String }

    @Test func stateMapUsesEnvironment() {
        let store = appStore(count: 3)
        let proj = store.projection(
            environment: Env(scale: 10, prefix: "n"),
            action: Reader { _ in { (a: Int) in AppAction(counter: a, other: nil) } },
            state: Reader { env in { (s: AppState) in "\(env.prefix)\(s.count * env.scale)" } }
        )
        #expect(proj.currentState == "n30") // 3 * 10, prefixed by "n"
    }

    @Test func actionMapUsesEnvironment() {
        let store = appStore(count: 0)
        let proj = store.projection(
            environment: Env(scale: 4, prefix: ""),
            action: Reader { env in { (a: Int) in AppAction(counter: a * env.scale, other: nil) } },
            state: Reader { _ in { (s: AppState) in s.count } }
        )
        proj.dispatch(2) // 2 * scale(4) forwarded to the underlying store
        #expect(store.currentState.count == 8)
    }

    @Test func stateReflectsLiveStoreChanges() {
        let store = appStore(count: 0)
        let proj = store.projection(
            environment: Env(scale: 2, prefix: ""),
            action: Reader { _ in { (a: Int) in AppAction(counter: a, other: nil) } },
            state: Reader { env in { (s: AppState) in s.count * env.scale } }
        )
        store.dispatch(AppAction(counter: 5, other: nil))
        #expect(proj.currentState == 10) // env applied to the freshly-read store state
    }
}
