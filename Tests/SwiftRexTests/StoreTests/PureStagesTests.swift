// SPDX-License-Identifier: Apache-2.0

import CoreFP
import Foundation
@testable import SwiftRex
import Testing

// The pure stages between stores — StoreProjection, StoreBuffer, StoreCollectionFocus, StoreOptionalFocus: they follow a stream, keep
// nothing a parent holds, run nothing until observed, and deliver synchronously on the main actor.

private enum RowAction: Sendable, Equatable { case rename(String) }
private struct Row: Sendable, Equatable, Identifiable { var id: Int; var title: String }

private enum AppAction: Sendable {
    case row(ElementAction<Int, RowAction>)
    case keyed(ElementAction<String, RowAction>)
    case mutate(Mutation)
}

private struct Mutation: Sendable { let apply: @Sendable (inout AppState) -> Void }

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let row = Prism<AppAction, ElementAction<Int, RowAction>>(
            preview: { if case let .row(v) = $0 { v } else { nil } }, review: AppAction.row)
        let keyed = Prism<AppAction, ElementAction<String, RowAction>>(
            preview: { if case let .keyed(v) = $0 { v } else { nil } }, review: AppAction.keyed)
    }
    static let prism = Prisms()
}

private struct AppState: Sendable, Equatable {
    var rows: [Row] = (1...5).map { Row(id: $0, title: "r\($0)") }
    var byKey: [String: Row] = ["a": Row(id: 1, title: "a")]
    var other = 0
    var optional: Row? = Row(id: 7, title: "seven")
}

@MainActor
private func makeStore(_ initial: AppState = AppState()) -> Store<AppAction, AppState, Void> {
    Store(
        initial: initial,
        reducer: Reducer.reduce { (action: AppAction, state: inout AppState) in
            switch action {
            case let .row(element):
                if case let .rename(title) = element.action, let index = state.rows.firstIndex(where: { $0.id == element.id }) {
                    state.rows[index].title = title
                }
            case let .keyed(element):
                if case let .rename(title) = element.action { state.byKey[element.id]?.title = title }
            case let .mutate(mutation):
                mutation.apply(&state)
            }
        }
    )
}

private typealias RowLane = Relay.StateAxis.Keyed<AppState, [Row], Int, Row>
private typealias RowScope = Relay.Scope<
    AppAction, Relay.ActionAxis.Element<AppAction, Int, RowAction>, AppState, RowLane, Never, Relay.Absurd<Never>
>

private func mutate(_ apply: @escaping @Sendable (inout AppState) -> Void) -> AppAction { .mutate(Mutation(apply: apply)) }

@Suite("Pure stages — StoreCollectionFocus")
@MainActor
struct StoreCollectionFocusTests {
    @Test func followsItsElementByIDAcrossReordersInsertsAndRemoval() {
        let store = makeStore()
        let row = store.projection(.action(AppAction.prism.row).state(\AppState.rows), element: 3)
        var seen: [String?] = []
        let token = row.stateStream.observe { seen.append($0?.title) }
        store.dispatch(mutate { $0.rows.reverse() })
        store.dispatch(mutate { $0.rows.insert(Row(id: 99, title: "top"), at: 0) })
        store.dispatch(mutate { $0.rows[3].title = "R3" })               // [99, 5, 4, 3, 2, 1]: id 3 is at index 3
        store.dispatch(mutate { $0.rows.removeAll { $0.id == 3 } })
        store.dispatch(mutate { $0.rows.append(Row(id: 3, title: "back")) })
        // current, reverse, insert-at-top, rename, removed (nil), re-added
        #expect(seen == ["r3", "r3", "r3", "R3", nil, "back"])
        _ = token
    }

    @Test func dispatchesThroughTheElementLane() {
        let store = makeStore()
        let row = store.projection(.action(AppAction.prism.row).state(\AppState.rows), element: 2)
        row.dispatch(.rename("two"))
        #expect(store.currentState.rows.first { $0.id == 2 }?.title == "two")
    }

    @Test func eachObserverKeepsItsOwnHint() {
        let store = makeStore()
        let row = store.projection(.action(AppAction.prism.row).state(\AppState.rows), element: 4)
        var first: [String?] = []
        var second: [String?] = []
        let a = row.stateStream.observe { first.append($0?.title) }
        store.dispatch(mutate { $0.rows.reverse() })
        let b = row.stateStream.observe { second.append($0?.title) }     // subscribes after the move
        store.dispatch(mutate { $0.rows.shuffle() })
        #expect(first == ["r4", "r4", "r4"])
        #expect(second == ["r4", "r4"])
        _ = (a, b)
    }

    @Test func byPositionAndByKey() {
        let store = makeStore()
        let atZero = store.projection(.action(AppAction.prism.row).state(indexed: \AppState.rows), element: 0)
        let keyed = store.projection(.action(AppAction.prism.keyed).state(dictionary: \AppState.byKey), element: "a")
        #expect(atZero.currentState?.title == "r1")
        store.dispatch(mutate { $0.rows.removeFirst() })
        #expect(atZero.currentState?.title == "r2")                       // the position now holds another row
        keyed.dispatch(.rename("A"))
        #expect(keyed.currentState?.title == "A")
    }

    @Test func aLaneWithoutALocatorStillWorks() {
        let store = makeStore()
        let lane = Relay.StateAxis.Keyed<AppState, [Row], Int, Row>(
            container: lens(\AppState.rows),
            element: { [Row].ix(id: $0) },
            ids: { $0.map(\.id) }
        )
        let scope = RowScope(
            action: .init(AppAction.prism.row), state: lane, environment: .init()
        )
        let row = store.projection(scope, element: 5)
        store.dispatch(mutate { $0.rows.reverse() })
        #expect(row.currentState?.title == "r5")
    }

    @Test func nothingRunsUntilObservedAndNothingIsKeptAfter() {
        let store = makeStore()
        let reads = LockProtected(0)
        let lane = Relay.StateAxis.Keyed<AppState, [Row], Int, Row>(
            container: Lens(
                get: { reads.mutate { $0 += 1 }; return $0.rows },
                set: { whole, rows in var copy = whole; copy.rows = rows; return copy }
            ),
            element: { [Row].ix(id: $0) },
            ids: { $0.map(\.id) }
        )
        let scope = RowScope(
            action: .init(AppAction.prism.row), state: lane, environment: .init()
        )
        let row = store.projection(scope, element: 1)
        store.dispatch(mutate { $0.other += 1 })
        #expect(reads.value == 0)                                         // lazy: no observer, no work
        var token: UISubscriptionToken? = row.stateStream.observe { _ in }
        let whileObserved = reads.value
        token = nil // unsubscribe
        store.dispatch(mutate { $0.other += 1 })
        #expect(reads.value == whileObserved)                                   // nothing kept running after it
        _ = token
    }
}

@Suite("Pure stages — StoreOptionalFocus")
@MainActor
struct StoreOptionalFocusTests {
    @Test func holdsTheLastPresentValuePerObserver() {
        let store = makeStore()
        let slot = store.projection(action: { AppAction.row(ElementAction(7, action: $0)) }, state: \AppState.optional)
        let unwrapped = StoreOptionalFocus(slot, present: Row(id: 7, title: "seven"))
        var seen: [String] = []
        let token = unwrapped.stateStream.observe { seen.append($0.title) }
        store.dispatch(mutate { $0.optional?.title = "SEVEN" })
        store.dispatch(mutate { $0.optional = nil })
        #expect(seen == ["seven", "SEVEN", "SEVEN"])
        _ = token
    }

    @Test func startsFromPresentWhenTheUpstreamIsAlreadyNil() {
        var initial = AppState()
        initial.optional = nil
        let store = makeStore(initial)
        let unwrapped = StoreOptionalFocus(store.projection(action: { $0 }, state: \AppState.optional), present: Row(id: 0, title: "seed"))
        #expect(unwrapped.currentState.title == "seed")
    }
}

@Suite("Pure stages — one synchronous chain on the main actor")
@MainActor
struct PureChainTests {
    @Test func aDispatchReachesTheEndOfTheChainBeforeItReturns() {
        let store = makeStore()
        let chain = StoreOptionalFocus(
            store
                .projection(action: { $0 }, state: { $0 })
                .buffer()
                .projection(.action(AppAction.prism.row).state(\AppState.rows), element: 2),
            present: Row(id: 2, title: "r2")
        )
        var delivered: String?
        let token = chain.stateStream.observe { delivered = $0.title }
        store.dispatch(.row(ElementAction(2, action: .rename("now"))))
        #expect(delivered == "now") // no hop: already there when dispatch returns (the test runs on the main actor)
        _ = token
    }
}
