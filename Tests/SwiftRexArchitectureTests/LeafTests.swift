// SPDX-License-Identifier: Apache-2.0

// The model: pure stages all the way (Store → projection → buffer → element → unwrap), and the ViewStore as the only
// owned leaf, where observation happens. These tests check the functional requirements end to end.

#if canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import Combine
    import CoreFP
    import Foundation
    import Observation
    @testable import SwiftRex
    @testable import SwiftRexSwiftUI
    import SwiftUI
    import Testing

    private final class Hits: @unchecked Sendable {
        // Bumped from synchronous observation callbacks on the main actor only.
        private let lock = NSLock()
        private var n = 0
        var value: Int { lock.withLock { n } }
        func bump() { lock.withLock { n += 1 } }
    }

    private struct Row: Sendable, Equatable, Identifiable { var id: Int; var title: String }

    private final class LockProtectedCounter: @unchecked Sendable {
        // Bumped from state maps, which run on the main actor.
        private let lock = NSLock()
        private var n = 0
        var value: Int { lock.withLock { n } }
        func bump() { lock.withLock { n += 1 } }
    }
    private enum RowAction: Sendable, Equatable { case rename(String) }

    private struct ListState: Sendable, Equatable {
        var rows: [Row] = (1...5).map { Row(id: $0, title: "r\($0)") }
        var other = 0
        var playhead = 0
    }

    private struct Mutation: Sendable { let apply: @Sendable (inout ListState) -> Void }

    private enum ListAction: Sendable {
        case row(ElementAction<Int, RowAction>)
        case mutate(Mutation)
    }

    extension ListAction: Prismatic {
        struct Prisms: Sendable {
            let row = Prism<ListAction, ElementAction<Int, RowAction>>(
                preview: { if case let .row(v) = $0 { v } else { nil } }, review: ListAction.row)
        }
        static let prism = Prisms()
    }

    private func mutate(_ apply: @escaping @Sendable (inout ListState) -> Void) -> ListAction { .mutate(Mutation(apply: apply)) }

    @MainActor
    private func makeStore(_ initial: ListState = ListState()) -> Store<ListAction, ListState, Void> {
        Store(
            initial: initial,
            reducer: Reducer.reduce { (action: ListAction, state: inout ListState) in
                switch action {
                case let .row(element):
                    if case let .rename(title) = element.action, let index = state.rows.firstIndex(where: { $0.id == element.id }) {
                        state.rows[index].title = title
                    }
                case let .mutate(mutation):
                    mutation.apply(&state)
                }
            }
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private func track(_ read: () -> Void) -> Hits {
        let hits = Hits()
        withObservationTracking(read) { hits.bump() }
        return hits
    }

    // MARK: - One synchronous chain, dispatch → view store signal

    @Suite("Leaf — one synchronous chain on the main actor")
    @MainActor
    struct LeafChainTests {
        @Test func combineSignalFiresInsideTheDispatchAndInsideWithAnimation() {
            let store = makeStore()
            let row = StoreOptionalFocus(
                store.projection(action: { $0 }, state: { $0 }).buffer().projection(.action(ListAction.prism.row).state(\ListState.rows), element: 2),
                present: Row(id: 2, title: "r2")
            ).viewStore(.combine)
            _ = row.state.title
            var signalled = false
            let cancellable = row.testSignal.objectWillChange.sink { signalled = true }
            withAnimation(.linear) {
                store.dispatch(.row(ElementAction(2, action: .rename("now"))))
                #expect(signalled)                                          // already, inside the animation's transaction
            }
            #expect(row.state.title == "now")
            cancellable.cancel()
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func observationInvalidatesInsideTheDispatch() {
            let store = makeStore()
            let row = StoreOptionalFocus(
                store.projection(action: { $0 }, state: { $0 }).buffer().projection(.action(ListAction.prism.row).state(\ListState.rows), element: 2),
                present: Row(id: 2, title: "r2")
            ).viewStore(.observation)
            let title = track { _ = row.state.title }
            withAnimation(.linear) {
                store.dispatch(.row(ElementAction(2, action: .rename("now"))))
                #expect(title.value == 1)                                   // willSet reached SwiftUI inside the call
            }
        }
    }

    // MARK: - Invalidation: parent and children independent

    @Suite("Leaf — invalidation")
    @MainActor
    struct LeafInvalidationTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func aRowRedrawsForItsOwnElementOnlyAndTheListForMembershipOnly() {
            let store = makeStore()
            let list = store.viewStore(.observation)
            var rowStores: [Int: StoreOptionalFocus<RowAction, Row>] = [:]
            let listBody = track {
                for row in list.state.each(\.rows) {
                    rowStores[row.id] = list.traverse(.action(ListAction.prism.row).state(\ListState.rows), element: row.id)
                }
            }
            let rows = rowStores.mapValues { $0.viewStore(.observation) }     // each row owned (by the test)
            let reads = rows.mapValues { row in track { _ = row.state.title } }
            store.dispatch(.row(ElementAction(3, action: .rename("R3"))))
            #expect(reads[3]?.value == 1)
            #expect(reads.filter { $0.key != 3 }.allSatisfy { $0.value.value == 0 })
            #expect(listBody.value == 0)                                      // the list doesn't redraw for a row's content
            store.dispatch(mutate { $0.other += 1 })
            #expect(listBody.value == 0)
            #expect(rows[3]?.state.title == "R3")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func reordersAndInsertsDontRedrawRowsWhoseContentDidNotChange() {
            let store = makeStore()
            let list = store.viewStore(.observation)
            let rows = (1...5).compactMap { id in
                list.traverse(.action(ListAction.prism.row).state(\ListState.rows), element: id)?.viewStore(.observation)
            }
            let reads = rows.map { row in track { _ = row.state.title } }
            store.dispatch(mutate { $0.rows.reverse() })
            store.dispatch(mutate { $0.rows.insert(Row(id: 99, title: "top"), at: 0) })
            #expect(reads.allSatisfy { $0.value == 0 })
            #expect(rows.map(\.state.title) == ["r1", "r2", "r3", "r4", "r5"])
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func removalFlipsThePresenceEdgeAndTheRowHoldsItsLastValue() {
            let store = makeStore()
            let list = store.viewStore(.observation)
            var slot: StoreOptionalFocus<RowAction, Row>?
            let presence = track { slot = list.traverse(.action(ListAction.prism.row).state(\ListState.rows), element: 4) }
            let row = slot?.viewStore(.observation)
            store.dispatch(.row(ElementAction(4, action: .rename("R4"))))
            #expect(presence.value == 0)                                      // content: not the edge
            store.dispatch(mutate { $0.rows.removeAll { $0.id == 4 } })
            #expect(presence.value == 1)
            #expect(list.traverse(.action(ListAction.prism.row).state(\ListState.rows), element: 4) == nil)
            #expect(row?.state.title == "R4")
        }

        @Test func aDroppedChildLeavesNothingBehind() {
            let store = makeStore()
            let list = store.viewStore(.combine)
            let reads = LockProtectedCounter()
            weak var engine: ViewStoreSignal?
            do {
                let child = StoreOptionalFocus(
                    list.projection(action: { $0 }, state: { (state: ListState) -> ListState in reads.bump(); return state })
                        .projection(.action(ListAction.prism.row).state(\ListState.rows), element: 1),
                    present: Row(id: 1, title: "r1")
                ).viewStore(.combine)
                engine = child.testSignal
                _ = child.state.title
                #expect(engine != nil)
            }
            #expect(engine == nil)                                            // the child's view store is gone
            let before = reads.value
            store.dispatch(.row(ElementAction(1, action: .rename("R1"))))
            #expect(reads.value == before)                                    // and nothing still follows the store for it
        }

        @Test func aRowDispatchesThroughItsElementLane() {
            let store = makeStore()
            let row = store.viewStore(.combine).traverse(.action(ListAction.prism.row).state(\ListState.rows), element: 5)?.viewStore(.combine)
            row?.dispatch(.rename("five"))
            #expect(store.currentState.rows.last?.title == "five")
        }
    }

    // MARK: - A view store forwards its upstream; each

    private typealias RowScope = Relay.Scope<
        ListAction,
        Relay.ActionAxis.Element<ListAction, Int, RowAction>,
        ListState,
        Relay.StateAxis.Keyed<ListState, [Row], Int, Row>,
        Never,
        Relay.Absurd<Never>
    >
    private let rowScope: RowScope = .action(ListAction.prism.row).state(\ListState.rows)

    @Suite("Leaf — forwarding and each")
    @MainActor
    struct LeafForwardingTests {
        @Test func theParentChainRunsOncePerChangeHoweverManyChildren() {
            let store = makeStore(ListState(rows: (0..<50).map { Row(id: $0, title: "\($0)") }))
            let maps = LockProtectedCounter()
            let list = store
                .projection(action: { $0 }, state: { (state: ListState) -> ListState in
                    maps.bump()
                    return state
                })
                .viewStore(.combine)
            let rows = list.each(rowScope).map { $0.viewStore(.combine) }
            let before = maps.value
            store.dispatch(.row(ElementAction(7, action: .rename("seven"))))
            #expect(maps.value - before == 1)                                // not once per row
            #expect(rows[7].state.title == "seven")
        }

        @Test func childrenGetEveryUpstreamValueEvenWhenTheParentReadsNothing() {
            let store = makeStore()
            let list = store.viewStore(.combine)                             // no view read anything from it
            var seen: [Int] = []
            let token = list.projection(action: { $0 }, state: \.other).stateStream.observe { seen.append($0) }
            store.dispatch(mutate { $0.other = 1 })
            store.dispatch(mutate { $0.other = 2 })
            #expect(seen == [0, 1, 2])
            _ = token
        }

        @Test func eachGivesOneIdentifiedStorePerElementInOrder() {
            let store = makeStore()
            let list = store.viewStore(.combine)
            let items = list.each(rowScope)
            #expect(items.map(\.id) == [1, 2, 3, 4, 5])
            #expect(items.map { $0.viewStore(.combine).state.title } == ["r1", "r2", "r3", "r4", "r5"])
            items[2].dispatch(.rename("three"))
            #expect(store.currentState.rows[2].title == "three")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func eachDependsOnTheIdsOnly() {
            let store = makeStore()
            let list = store.viewStore(.observation)
            let edit = track { _ = list.each(rowScope) }
            store.dispatch(.row(ElementAction(2, action: .rename("two"))))
            #expect(edit.value == 0)                                         // a change inside an element: not the list
            let insert = track { _ = list.each(rowScope) }
            store.dispatch(mutate { $0.rows.append(Row(id: 9, title: "nine")) })
            #expect(insert.value == 1)
        }

        @Test func anItemHoldsItsLastValueOnceRemoved() {
            let store = makeStore()
            let item = store.viewStore(.combine).each(rowScope)[0].viewStore(.combine)
            store.dispatch(mutate { $0.rows.removeFirst() })
            #expect(item.state.title == "r1")
        }
    }

    // MARK: - BusDriver-shaped: many eager elements, a 10 Hz playhead

    @Suite("Leaf — many eager elements and a hot playhead", .serialized)
    @MainActor
    struct LeafPlayheadTests {
        #if DEBUG
            static let count = 300
        #else
            static let count = 3_000
        #endif
        static let ticks = 50

        private func manyRows() -> Store<ListAction, ListState, Void> {
            var initial = ListState()
            initial.rows = (0..<Self.count).map { Row(id: $0, title: "\($0)") }
            return makeStore(initial)
        }

        // A parent chain in front of the list, like a feature's view projection.
        private func viewChain(_ store: Store<ListAction, ListState, Void>) -> some StoreType<ListAction, ListState> {
            store.projection(action: { $0 }, state: { $0 }).buffer()
        }

        private func tick(_ store: Store<ListAction, ListState, Void>) -> Duration {
            ContinuousClock().measure {
                for _ in 0..<Self.ticks { store.dispatch(mutate { $0.playhead += 1 }) }
            }
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func positionsFromOneViewStore() {
            let store = manyRows()
            let list = viewChain(store).viewStore(.observation)
            let reads = track { list.state.each(\.rows).forEach { _ = $0.title } }
            let elapsed = withExtendedLifetime(list) { tick(store) } // release builds end lifetimes at the last use
            #expect(reads.value == 0)
            #expect(elapsed / Self.ticks < .milliseconds(1)) // unchanged rows are skipped at the `\.rows` guard
            print("PLAYHEAD positions rows=\(Self.count) perTick=\(elapsed / Self.ticks)")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func aViewStorePerElementFollowingTheParentViewStore() {
            let store = manyRows()
            let list = viewChain(store).viewStore(.observation)
            let rows = list.each(rowScope).map { $0.viewStore(.observation) }
            let reads = track { rows.forEach { _ = $0.state.title } }
            let elapsed = withExtendedLifetime((list, rows)) { tick(store) } // release builds end lifetimes at the last use
            #expect(reads.value == 0)
            print("PLAYHEAD perElement-forwarded rows=\(Self.count) perTick=\(elapsed / Self.ticks)")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func aViewStorePerElementEachReRunningTheChain() {
            // What every row did before forwarding: follow the parent's pure chain on its own.
            let store = manyRows()
            let chain = viewChain(store)
            let rows = (0..<Self.count).compactMap { id in
                StoreOptionalFocus(chain.projection(rowScope, element: id), present: Row(id: id, title: "\(id)")).viewStore(.observation)
            }
            let reads = track { rows.forEach { _ = $0.state.title } }
            let elapsed = withExtendedLifetime(rows) { tick(store) } // release builds end lifetimes at the last use
            #expect(reads.value == 0)
            print("PLAYHEAD perElement-rerun rows=\(Self.count) perTick=\(elapsed / Self.ticks)")
        }
    }

    // MARK: - Collections: performance

    @Suite("Leaf — many owned rows")
    @MainActor
    struct LeafPerformanceTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func changesStayCheapWithManyOwnedRows() {
            // 1,000 rows in release (the numbers in the docs); 200 in debug, so the suite doesn't hold the main actor
            // for seconds and starve timing-sensitive tests running alongside.
            #if DEBUG
                let count = 200
            #else
                let count = 1_000
            #endif
            var initial = ListState()
            initial.rows = (0..<count).map { Row(id: $0, title: "\($0)") }
            let store = makeStore(initial)
            let list = store.viewStore(.observation)
            let clock = ContinuousClock()
            var rows: [ViewStore<RowAction, Row>] = []
            let build = clock.measure {
                rows = (0..<count).compactMap { id in
                    list.traverse(.action(ListAction.prism.row).state(\ListState.rows), element: id)?.viewStore(.observation)
                }
            }
            func arm() { rows.forEach { row in _ = track { _ = row.state.title } } }
            arm()
            let steady = clock.measure { for tick in 0..<20 { store.dispatch(.row(ElementAction(count - 1, action: .rename("t\(tick)")))) } }
            arm()
            let insertTop = clock.measure { store.dispatch(mutate { $0.rows.insert(Row(id: 5_000, title: "top"), at: 0) }) }
            arm()
            let blockRows = (6_000..<6_010).map { Row(id: $0, title: "b") }
            let block = clock.measure { store.dispatch(mutate { $0.rows.insert(contentsOf: blockRows, at: 0) }) }
            arm()
            let reverse = clock.measure { store.dispatch(mutate { $0.rows.reverse() }) }
            #expect(rows.count == count)
            #expect(rows[count / 2].state.title == "\(count / 2)")
            print("LEAF-COST rows=\(count) build=\(build) steady20=\(steady) insertTop=\(insertTop) block10=\(block) reverse=\(reverse)")
            #expect(steady < .seconds(2))
            #expect(insertTop < .seconds(1))
            #expect(block < .seconds(1))
            #expect(reverse < .seconds(2))
        }
    }
#endif

#if canImport(AppKit) && canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import AppKit

    @MainActor
    private final class ListRenders {
        var list = 0
        var rows: [Int: Int] = [:]
        var rowMakes = 0
    }

    // A row keeps its own view store, made once from the pure stage it's handed.
    private struct HostedRow: View {
        @OwnedStore var viewStore: ViewStore<RowAction, Row>
        let renders: ListRenders
        init(store: some StoreType<RowAction, Row>, renders: ListRenders) {
            _viewStore = OwnedStore(wrappedValue: {
                renders.rowMakes += 1
                return store.viewStore()
            }())
            self.renders = renders
        }
        var body: some View {
            renders.rows[viewStore.state.value.id, default: 0] += 1
            return Text(viewStore.state.title)
        }
    }

    private struct HostedList: View {
        let viewStore: ViewStore<ListAction, ListState>
        let renders: ListRenders
        var body: some View {
            renders.list += 1
            return VStack {
                ForEach(viewStore.each(.action(ListAction.prism.row).state(\ListState.rows))) { row in
                    HostedRow(store: row, renders: renders)
                }
            }
        }
    }

    private struct HostedRoot: View {
        @OwnedStore var viewStore: ViewStore<ListAction, ListState>
        let renders: ListRenders
        init(_ store: Store<ListAction, ListState, Void>, _ strategy: ViewStrategy, _ renders: ListRenders) {
            _viewStore = OwnedStore(wrappedValue: store.viewStore(strategy))
            self.renders = renders
        }
        var body: some View { HostedList(viewStore: viewStore, renders: renders) }
    }

    @MainActor
    private func hostedList(_ store: Store<ListAction, ListState, Void>, _ strategy: ViewStrategy, _ renders: ListRenders) -> some View {
        HostedRoot(store, strategy, renders)
    }

    @MainActor
    private func settle(_ view: NSHostingView<some View>) {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    @Suite("Leaf — hosted in SwiftUI")
    @MainActor
    struct LeafHostedTests {
        @available(macOS 14, *)
        @Test func aRowChangeRedrawsThatRowOnlyAndRowsAreBuiltOnce() {
            let store = makeStore()
            let renders = ListRenders()
            let host = NSHostingView(rootView: hostedList(store, .observation, renders))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 400)
            settle(host)
            #expect(renders.rowMakes == 5)
            let listBefore = renders.list
            let rowsBefore = renders.rows
            store.dispatch(.row(ElementAction(3, action: .rename("R3"))))
            settle(host)
            #expect(renders.list == listBefore)                             // the list didn't redraw for a row's content
            #expect(renders.rows[3] == (rowsBefore[3] ?? 0) + 1)            // row 3 did
            #expect(renders.rows.filter { $0.key != 3 } == rowsBefore.filter { $0.key != 3 })
            #expect(renders.rowMakes == 5)                                  // no row view store rebuilt
        }

        @available(macOS 14, *)
        @Test func reordersAndInsertsKeepEachRowsOwnedStore() {
            let store = makeStore()
            let renders = ListRenders()
            let host = NSHostingView(rootView: hostedList(store, .observation, renders))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 400)
            settle(host)
            store.dispatch(mutate { $0.rows.reverse() })
            settle(host)
            #expect(renders.rowMakes == 5)                                  // same ids: the same owned row stores
            store.dispatch(mutate { $0.rows.insert(Row(id: 42, title: "new"), at: 2) })
            settle(host)
            #expect(renders.rowMakes == 6)                                  // only the new row got one
            store.dispatch(mutate { $0.rows.removeAll { $0.id == 42 } })
            settle(host)
            #expect(renders.rowMakes == 6)
        }

        @Test func combineRedrawsTheChangedRow() {
            let store = makeStore()
            let renders = ListRenders()
            let host = NSHostingView(rootView: hostedList(store, .combine, renders))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 400)
            settle(host)
            let before = renders.rows[2] ?? 0
            store.dispatch(.row(ElementAction(2, action: .rename("R2"))))
            settle(host)
            #expect((renders.rows[2] ?? 0) > before)
        }
    }
#endif
