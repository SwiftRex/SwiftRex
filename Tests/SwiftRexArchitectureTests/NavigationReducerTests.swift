#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
@testable import SwiftRexArchitecture
import Testing

private enum NavRoute: Hashable, Sendable { case a, b, c }
private struct NavItem: Sendable, Equatable { var id: Int }
private enum NavTab: Hashable, Sendable { case home, search }

// @Prisms requires >= fileprivate.
// swiftlint:disable private_over_fileprivate
@Prisms
fileprivate enum NavAction: Sendable {
    case stack(StackNavigation<NavRoute>)
    case modal(ModalNavigation<NavItem>)
    case select(SelectionNavigation<NavTab>)
}
// swiftlint:enable private_over_fileprivate

private struct NavState: Sendable, Equatable {
    var path: [NavRoute] = []
    var sheet: NavItem?
    var tab: NavTab = .home
    var locked = false
}

@Suite("Navigation reducer")
@MainActor
struct NavigationReducerTests {
    private func makeStore(_ behavior: Behavior<NavAction, NavState, Void>, _ initial: NavState = .init()) -> Store<NavAction, NavState, Void> {
        Store(initial: initial, behavior: behavior, environment: ())
    }

    // MARK: Stack

    @Test func stackPushPopSetPath() {
        let store = makeStore(.navigationStack(\.path, action: \.stack))
        store.dispatch(.stack(.push(.a)))
        store.dispatch(.stack(.push(.b)))
        #expect(store.state.path == [.a, .b])
        store.dispatch(.stack(.pop))
        #expect(store.state.path == [.a])
        store.dispatch(.stack(.setPath([.a, .b, .c])))
        #expect(store.state.path == [.a, .b, .c])
        store.dispatch(.stack(.popToRoot))
        #expect(store.state.path == [])
    }

    @Test func stackVetoBlocks() {
        // block pop while locked
        let store = makeStore(
            .navigationStack(\.path, action: \.stack) { op, state in
                if case .pop = op, state.locked { return false }
                return true
            },
            NavState(path: [.a, .b], locked: true)
        )
        store.dispatch(.stack(.pop))
        #expect(store.state.path == [.a, .b])   // vetoed
    }

    // MARK: Modal

    @Test func modalPresentDismiss() {
        let store = makeStore(.navigationItem(\.sheet, action: \.modal))
        store.dispatch(.modal(.present(.init(id: 7))))
        #expect(store.state.sheet == NavItem(id: 7))
        store.dispatch(.modal(.dismiss))
        #expect(store.state.sheet == nil)
    }

    @Test func modalVetoBlocksDismiss() {
        let store = makeStore(
            .navigationItem(\.sheet, action: \.modal) { op, _ in
                if case .dismiss = op { return false }
                return true
            },
            NavState(sheet: NavItem(id: 1))
        )
        store.dispatch(.modal(.dismiss))
        #expect(store.state.sheet == NavItem(id: 1))   // vetoed
    }

    // MARK: Selection

    @Test func selectionSelects() {
        let store = makeStore(.navigationSelection(\.tab, action: \.select))
        store.dispatch(.select(.select(.search)))
        #expect(store.state.tab == .search)
    }

    @Test func selectionVetoBlocks() {
        let store = makeStore(
            .navigationSelection(\.tab, action: \.select) { _, state in !state.locked },
            NavState(locked: true)
        )
        store.dispatch(.select(.select(.search)))
        #expect(store.state.tab == .home)   // vetoed
    }

    // MARK: Composition — nav reducers fold with feature behaviors

    @Test func foldsWithOtherBehaviors() {
        let app = Behavior<NavAction, NavState, Void>.combine([
            .navigationStack(\.path, action: \.stack),
            .navigationItem(\.sheet, action: \.modal)
        ])
        let store = makeStore(app)
        store.dispatch(.stack(.push(.a)))
        store.dispatch(.modal(.present(.init(id: 2))))
        #expect(store.state.path == [.a])
        #expect(store.state.sheet == NavItem(id: 2))
    }
}
#endif
