// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import CoreFP
    import Foundation
    import FPMacros
    import Observation
    @testable import SwiftRex
    @testable import SwiftRexSwiftUI
    import Testing

    // MARK: - Fixtures

    private final class Hits: @unchecked Sendable {
        // Bumped from synchronous Observation callbacks on the main actor only.
        private let lock = NSLock()
        private var n = 0
        var value: Int { lock.withLock { n } }
        func bump() { lock.withLock { n += 1 } }
    }

    // @Prisms requires >= fileprivate.
    // swiftlint:disable private_over_fileprivate
    fileprivate struct Row: Sendable, Equatable, Identifiable {
        var id: Int
        var title: String
        var slug: String { "row-\(id)" }
    }

    @Prisms
    fileprivate enum RowAction: Sendable, Equatable {
        case rename(String)
    }

    fileprivate struct ListState: Sendable, Equatable {
        var rows: [Row] = (1...3).map { Row(id: $0, title: "r\($0)") }
        var byKey: [String: Row] = ["a": Row(id: 1, title: "a"), "b": Row(id: 2, title: "b")]
        var other = 0
    }

    @Prisms
    fileprivate enum ListAction: Sendable {
        case row(ElementAction<Int, RowAction>)
        case keyed(ElementAction<String, RowAction>)
        case slugged(ElementAction<String, RowAction>)
        case mutate(Mutation)
    }

    // A struct, not a bare closure payload: FP's `@Prisms` can't expand a case whose payload is a function type.
    fileprivate struct Mutation: Sendable {
        let apply: @Sendable (inout ListState) -> Void
    }

    // swiftlint:enable private_over_fileprivate

    extension ListAction {
        static func mutate(_ apply: @escaping @Sendable (inout ListState) -> Void) -> ListAction { .mutate(Mutation(apply: apply)) }
    }

    @MainActor
    private func makeStore(_ initial: ListState = ListState()) -> Store<ListAction, ListState, Void> {
        Store(
            initial: initial,
            behavior: Reducer.reduce { (action: ListAction, state: inout ListState) in
                switch action {
                case let .row(element):
                    if case let .rename(title) = element.action, let index = state.rows.firstIndex(where: { $0.id == element.id }) {
                        state.rows[index].title = title
                    }
                case let .keyed(element):
                    if case let .rename(title) = element.action { state.byKey[element.id]?.title = title }
                case let .slugged(element):
                    if case let .rename(title) = element.action, let index = state.rows.firstIndex(where: { $0.slug == element.id }) {
                        state.rows[index].title = title
                    }
                case let .mutate(mutation):
                    mutation.apply(&state)
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private func track(_ read: () -> Void) -> Hits {
        let hits = Hits()
        withObservationTracking(read) { hits.bump() }
        return hits
    }

    // MARK: - Focus by id

    @Suite("ViewStore — focus on a collection element")
    @MainActor
    struct CollectionFocusTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func byIDReadsGranularlyAndStaysAnchoredAcrossReorders() {
            let store = makeStore()
            let viewStore = store.viewStore(.observation)
            let row = viewStore.focus(.action(\.row).state(\.rows), element: 2)
            #expect(row.state.value?.title == "r2")
            let title = track { _ = row.state.value?.title }
            store.dispatch(.mutate { $0.rows[0].title = "R1" })          // a sibling
            store.dispatch(.mutate { $0.other += 1 })                   // outside the collection
            #expect(title.value == 0)
            store.dispatch(.mutate { $0.rows.reverse() })               // id 2 stays id 2
            #expect(title.value == 0)
            #expect(row.state.value?.title == "r2")
            let again = track { _ = row.state.value?.title }
            store.dispatch(.mutate { $0.rows.insert(Row(id: 9, title: "new"), at: 0) }) // everything shifts
            #expect(again.value == 0)
            #expect(row.state.value?.title == "r2")
        }

        @Test func dispatchesThroughTheElementLane() {
            let store = makeStore()
            let row = store.viewStore(.combine).focus(.action(\.row).state(\.rows), element: 3)
            row.dispatch(.rename("three"))
            #expect(store.currentState.rows.first { $0.id == 3 }?.title == "three")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func transposesToARowStoreThatOutlivesRemoval() {
            let store = makeStore()
            let viewStore = store.viewStore(.observation)
            let slot = viewStore.focus(.action(\.row).state(\.rows), element: 2)
            var rowStore: ViewStore<RowAction, Row>?
            let edge = track { rowStore = slot.transpose() }
            let title = track { _ = rowStore?.state.title }
            store.dispatch(.mutate { $0.rows[1].title = "R2" })
            #expect(edge.value == 0)                                    // the caller depends on presence only
            #expect(title.value == 1)
            #expect(rowStore?.state.title == "R2")
            store.dispatch(.mutate { $0.rows.removeAll { $0.id == 2 } })
            #expect(edge.value == 1)
            #expect(slot.transpose() == nil)
            #expect(rowStore?.state.title == "R2")                      // holds the last present value
        }

        @Test func aCustomIDKeyPath() {
            let store = makeStore()
            let row = store.viewStore(.combine).focus(.action(\.slugged).state(\.rows, id: \.slug), element: "row-3")
            #expect(row.state.value?.title == "r3")
            row.dispatch(.rename("slugged"))
            #expect(row.state.value?.title == "slugged")
        }

        @Test func byPositionFollowsThePosition() {
            let store = makeStore()
            let row = store.viewStore(.combine).focus(.action(\.row).state(indexed: \.rows), element: 0)
            #expect(row.state.value?.title == "r1")
            store.dispatch(.mutate { $0.rows.remove(at: 0) })
            #expect(row.state.value?.title == "r2")                    // position 0 now holds another row — the user's risk
            store.dispatch(.mutate { $0.rows.removeAll() })
            #expect(row.state.value == nil)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func byDictionaryKey() {
            let store = makeStore()
            let viewStore = store.viewStore(.observation)
            let entry = viewStore.focus(.action(\.keyed).state(dictionary: \.byKey), element: "b")
            let title = track { _ = entry.state.value?.title }
            store.dispatch(.mutate { $0.byKey["a"]?.title = "A" })
            #expect(title.value == 0)
            entry.dispatch(.rename("B"))
            #expect(title.value == 1)
            #expect(entry.state.value?.title == "B")
        }

        @Test func aLensLaneReadsCoarselyButCorrectly() {
            let store = makeStore()
            let lensLane: Lens<ListState, [Row]> = Lens(get: { $0.rows }, set: { whole, rows in var copy = whole; copy.rows = rows; return copy })
            let row = store.viewStore(.combine).focus(.action(\.row).state(lensLane), element: 1)
            #expect(row.state.value?.title == "r1")
            store.dispatch(.mutate { $0.rows.reverse() })
            #expect(row.state.value?.title == "r1")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func costStaysBoundedForAThousandFocusedRows() {
            var initial = ListState()
            initial.rows = (0..<1_000).map { Row(id: $0, title: "\($0)") }
            let store = makeStore(initial)
            let viewStore = store.viewStore(.observation)
            let rows = (0..<1_000).map { viewStore.focus(.action(\.row).state(\.rows), element: $0) }
            let clock = ContinuousClock()
            func arm() { rows.forEach { row in _ = track { _ = row.state.value?.title } } }
            arm()
            let steady = clock.measure {
                for tick in 0..<20 { store.dispatch(.mutate { $0.rows[999].title = "t\(tick)" }) }
            }
            arm()
            let insertAtTop = clock.measure { store.dispatch(.mutate { $0.rows.insert(Row(id: 5_000, title: "top"), at: 0) }) }
            arm()
            let reverse = clock.measure { store.dispatch(.mutate { $0.rows.reverse() }) }
            #expect(rows[500].state.value?.title == "500")
            // Before the hints, 20 steady changes cost ~5.5 s (release) — O(n) per row per change.
            #expect(steady < .seconds(1))
            #expect(insertAtTop < .seconds(1))
            #expect(reverse < .seconds(1))
        }
    }

    // MARK: - The lookup itself

    @Suite("ElementLookup — hints, neighbours, shift, table")
    struct ElementLookupTests {
        @Test func usesTheHintThenNeighboursThenTheLearnedShiftThenTheTable() {
            let clock = ElementLookupClock()
            let lookup = ElementLookup(clock: clock)
            let rows = (0..<10).map { Row(id: $0, title: "") }
            #expect(lookup.offset(of: 4, in: rows, identifier: \.id, hint: 4) == 4)            // hint
            let shifted = [Row(id: 99, title: "")] + rows                                       // one inserted at the top
            clock.generation += 1
            #expect(lookup.offset(of: 4, in: shifted, identifier: \.id, hint: 4) == 5)         // neighbour
            let block = (100..<103).map { Row(id: $0, title: "") } + rows                      // three inserted
            clock.generation += 1
            #expect(lookup.offset(of: 4, in: block, identifier: \.id, hint: 4) == 7)           // table (no shift yet)
            #expect(lookup.offset(of: 6, in: block, identifier: \.id, hint: 6) == 9)           // learned shift of 3
            #expect(lookup.offset(of: 42, in: block, identifier: \.id, hint: 1) == nil)        // absent
            #expect(lookup.offset(of: 8, in: rows.reversed(), identifier: \.id, hint: nil) == 1) // no hint: table
        }
    }
#endif
