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
                case .setName(let n): state.name = n
                case .presentEditor(let v): state.editor = v
                case .dismissEditor: state.editor = nil
                case .select(let item): state.selected = item
                case .deselect: state.selected = nil
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

// MARK: - Stack (path) + selection bindings

@Suite("StoreType navigation bindings — path & selection")
@MainActor
struct StoreNavBindingsTests {
    private enum Route: Hashable, Sendable { case a, b, c }
    private enum Tab: Hashable, Sendable { case home, search, profile }

    private struct S: Sendable, Equatable {
        var path: [Route] = []
        var tab: Tab = .home
        var sidebar: Route?
    }
    private enum A: Sendable, Equatable {
        case setPath([Route])
        case selectTab(Tab)
        case selectSidebar(Route?)
    }

    private func makeStore() -> Store<A, S, Void> {
        Store(
            initial: S(),
            behavior: Reducer.reduce { (action: A, state: inout S) in
                switch action {
                case .setPath(let p): state.path = p
                case .selectTab(let t): state.tab = t
                case .selectSidebar(let r): state.sidebar = r
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func pathReadsAndDispatchesWholeNewPath() async {
        let store = makeStore()
        store.dispatch(.setPath([.a]))
        await Task.yield()
        let path = store.path(\.path, set: A.setPath)
        #expect(path.wrappedValue == [.a])
        path.wrappedValue = [.a, .b] // SwiftUI push
        await Task.yield()
        #expect(store.state.path == [.a, .b])
        path.wrappedValue = [.a] // SwiftUI pop / back-swipe
        await Task.yield()
        #expect(store.state.path == [.a])
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func selectionDispatchesOnEveryChange() async {
        let store = makeStore()
        let tab = store.selection(\.tab, set: A.selectTab)
        #expect(tab.wrappedValue == .home)
        tab.wrappedValue = .search // selecting a tab is a real state change (not dismiss-only)
        await Task.yield()
        #expect(store.state.tab == .search)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func optionalSelectionHandlesNilAndValue() async {
        let store = makeStore()
        let sidebar = store.selection(\.sidebar, set: A.selectSidebar)
        #expect(sidebar.wrappedValue == nil)
        sidebar.wrappedValue = .c
        await Task.yield()
        #expect(store.state.sidebar == .c)
        sidebar.wrappedValue = nil // clearing the sidebar selection
        await Task.yield()
        #expect(store.state.sidebar == nil)
    }
}
#endif
