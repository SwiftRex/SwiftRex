// SPDX-License-Identifier: Apache-2.0

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
                    case let .setName(n): state.name = n
                    case let .presentEditor(v): state.editor = v
                    case .dismissEditor: state.editor = nil
                    case let .select(item): state.selected = item
                    case .deselect: state.selected = nil
                    }
                }.asBehavior(),
                environment: ()
            )
        }

        @Test func bindingGetReadsState() {
            #expect(makeStore().viewStore().binding(.state(\.name).action(review: A.setName)).wrappedValue == "a")
        }

        @Test func bindingSetDispatches() async {
            let store = makeStore()
            store.viewStore().binding(.state(\.name).action(review: A.setName)).wrappedValue = "z"
            await Task.yield()
            #expect(store.currentState.name == "z")
        }

        @Test func presenceIsFalseWhenNilTrueWhenSome() async {
            let store = makeStore()
            let presence: Binding<Bool> = store.viewStore().binding(.state(\.editor).action(review: { (_: Void) in .dismissEditor }))
            #expect(presence.wrappedValue == false)
            store.dispatch(.presentEditor(7))
            await Task.yield()
            #expect(presence.wrappedValue == true)
        }

        @Test func presenceSetFalseDispatchesDismiss() async {
            let store = makeStore()
            store.dispatch(.presentEditor(7))
            await Task.yield()
            let presence: Binding<Bool> = store.viewStore().binding(.state(\.editor).action(review: { (_: Void) in .dismissEditor }))
            presence.wrappedValue = false // SwiftUI dismissing
            await Task.yield()
            #expect(store.currentState.editor == nil)
        }

        @Test func presenceSetTrueIsIgnored() async {
            let store = makeStore()
            let presence: Binding<Bool> = store.viewStore().binding(.state(\.editor).action(review: { (_: Void) in .dismissEditor }))
            presence.wrappedValue = true // binding never drives presentation
            await Task.yield()
            #expect(store.currentState.editor == nil)
        }

        @Test func itemReadsAndDismisses() async {
            let store = makeStore()
            store.dispatch(.select(.init(id: 3)))
            await Task.yield()
            let item: Binding<Item?> = store.viewStore().binding(.state(\.selected).action(review: { (_: Void) in .deselect }))
            #expect(item.wrappedValue == Item(id: 3))
            item.wrappedValue = nil // SwiftUI clearing the sheet
            await Task.yield()
            #expect(store.currentState.selected == nil)
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
                    case let .setPath(p): state.path = p
                    case let .selectTab(t): state.tab = t
                    case let .selectSidebar(r): state.sidebar = r
                    }
                }.asBehavior(),
                environment: ()
            )
        }

        @Test func pathReadsAndDispatchesWholeNewPath() async {
            let store = makeStore()
            store.dispatch(.setPath([.a]))
            await Task.yield()
            let path = store.viewStore().binding(.state(\.path).action(review: A.setPath))
            #expect(path.wrappedValue == [.a])
            path.wrappedValue = [.a, .b] // SwiftUI push
            await Task.yield()
            #expect(store.currentState.path == [.a, .b])
            path.wrappedValue = [.a] // SwiftUI pop / back-swipe
            await Task.yield()
            #expect(store.currentState.path == [.a])
        }

        @Test func selectionDispatchesOnEveryChange() async {
            let store = makeStore()
            let tab = store.viewStore().binding(.state(\.tab).action(review: A.selectTab))
            #expect(tab.wrappedValue == .home)
            tab.wrappedValue = .search // selecting a tab is a real state change (not dismiss-only)
            await Task.yield()
            #expect(store.currentState.tab == .search)
        }

        @Test func optionalSelectionHandlesNilAndValue() async {
            let store = makeStore()
            let sidebar = store.viewStore().binding(.state(\.sidebar).action(review: A.selectSidebar))
            #expect(sidebar.wrappedValue == nil)
            sidebar.wrappedValue = .c
            await Task.yield()
            #expect(store.currentState.sidebar == .c)
            sidebar.wrappedValue = nil // clearing the sidebar selection
            await Task.yield()
            #expect(store.currentState.sidebar == nil)
        }
    }
#endif
