#if canImport(Observation) && canImport(SwiftUI)
import SwiftRex
@testable import SwiftRexArchitecture
import SwiftUI
import Testing

// Exercises the store-backed SwiftUI bindings (`binding` / `presence` / `item`) — get reads state,
// set dispatches, and presence/item only ever dispatch a dismiss.

@Suite("StoreType SwiftUI bindings")
@MainActor
struct StoreBindingsTests {
    private struct S: Sendable, Equatable {
        var name = "a"
        var editor: Int?
        var selected: Item?
    }
    private struct Item: Identifiable, Sendable, Equatable { var id: Int }
    private enum A: Sendable, Equatable {
        case setName(String)
        case presentEditor(Int)
        case dismissEditor
        case select(Item)
        case deselect
    }

    private func makeStore() -> Store<A, S, Void> {
        Store(
            initial: S(),
            behavior: Reducer.reduce { (action: A, state: inout S) in
                switch action {
                case .setName(let n):       state.name = n
                case .presentEditor(let v): state.editor = v
                case .dismissEditor:        state.editor = nil
                case .select(let item):     state.selected = item
                case .deselect:             state.selected = nil
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func bindingGetReadsState() {
        #expect(makeStore().binding(\.name, set: A.setName).wrappedValue == "a")
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func bindingSetDispatches() async {
        let store = makeStore()
        store.binding(\.name, set: A.setName).wrappedValue = "z"
        await Task.yield()
        #expect(store.state.name == "z")
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func presenceIsFalseWhenNilTrueWhenSome() async {
        let store = makeStore()
        let presence = store.presence(\.editor, dismiss: .dismissEditor)
        #expect(presence.wrappedValue == false)
        store.dispatch(.presentEditor(7))
        await Task.yield()
        #expect(presence.wrappedValue == true)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func presenceSetFalseDispatchesDismiss() async {
        let store = makeStore()
        store.dispatch(.presentEditor(7))
        await Task.yield()
        let presence = store.presence(\.editor, dismiss: .dismissEditor)
        presence.wrappedValue = false // SwiftUI dismissing
        await Task.yield()
        #expect(store.state.editor == nil)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func presenceSetTrueIsIgnored() async {
        let store = makeStore()
        let presence = store.presence(\.editor, dismiss: .dismissEditor)
        presence.wrappedValue = true // binding never drives presentation
        await Task.yield()
        #expect(store.state.editor == nil)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func itemReadsAndDismisses() async {
        let store = makeStore()
        store.dispatch(.select(.init(id: 3)))
        await Task.yield()
        let item = store.item(\.selected, dismiss: .deselect)
        #expect(item.wrappedValue == Item(id: 3))
        item.wrappedValue = nil // SwiftUI clearing the sheet
        await Task.yield()
        #expect(store.state.selected == nil)
    }
}
#endif
