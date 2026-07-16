// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum RowAction: Sendable, Equatable { case bump }
private struct Row: Sendable, Equatable, Identifiable { let id: Int; var name: String; var taps = 0 }

private enum ListAction: Sendable, Equatable { case reload }

private enum AppAction: Sendable, Equatable {
    case row(ElementAction<Int, RowAction>)
    case byName(ElementAction<String, RowAction>)
    case dict(ElementAction<String, RowAction>)
    case bulk(ListAction)                        // whole-collection projection
    case only(RowAction)                         // optional-child projection
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let row = Prism<AppAction, ElementAction<Int, RowAction>>(
            preview: { if case let .row(v) = $0 { v } else { nil } }, review: AppAction.row)
        let byName = Prism<AppAction, ElementAction<String, RowAction>>(
            preview: { if case let .byName(v) = $0 { v } else { nil } }, review: AppAction.byName)
        let dict = Prism<AppAction, ElementAction<String, RowAction>>(
            preview: { if case let .dict(v) = $0 { v } else { nil } }, review: AppAction.dict)
        let bulk = Prism<AppAction, ListAction>(
            preview: { if case let .bulk(v) = $0 { v } else { nil } }, review: AppAction.bulk)
        let only = Prism<AppAction, RowAction>(
            preview: { if case let .only(v) = $0 { v } else { nil } }, review: AppAction.only)
    }
    static let prism = Prisms()
}

private struct AppState: Sendable, Equatable {
    var rows: [Row] = []
    var dict: [String: Row] = [:]
    var only: Row?
}

private func rowBehavior() -> Behavior<RowAction, Row, Void> {
    .reduce { action, state in
        switch action {
        case .bump: state.taps += 1
        }
    }
}

@Suite("Relay.Scope collection — projection") @MainActor
struct RelayScopeCollectionProjectionTests {
    private func rows() -> [Row] { [Row(id: 1, name: "A"), Row(id: 2, name: "B"), Row(id: 3, name: "C")] }

    @Test func projectsElementByIdReadsAndDispatches() {
        let behavior = rowBehavior().liftCollection(
            .action(AppAction.prism.row).state(\AppState.rows).environment { (v: Void) in v })
        let store = Store<AppAction, AppState, Void>(initial: AppState(rows: rows()), behavior: behavior, environment: ())
        // read: projected state is the unwrapped-or-nil element
        let cell: StoreProjection<RowAction, Row?> = store.projection(
            .action(AppAction.prism.row).state(\AppState.rows), element: 2)
        #expect(cell.state == Row(id: 2, name: "B"))
        // dispatch through the projection routes to the global store (addressed at id 2)
        cell.dispatch(.bump)
        #expect(cell.state?.taps == 1)
        #expect(store.state.rows.map(\.taps) == [0, 1, 0])
    }

    @Test func absentElementProjectsNil() {
        let store = Store<AppAction, AppState, Void>(
            initial: AppState(rows: rows()), behavior: .identity, environment: ())
        let missing: StoreProjection<RowAction, Row?> = store.projection(
            .action(AppAction.prism.row).state(\AppState.rows), element: 99)
        #expect(missing.state == nil)
    }

    @Test func wholeCollectionProjection() {
        // The base projection over the whole collection — the list view iterates this, then makes a
        // per-element projection per cell. `.state(\.rows)` resolves to ReadsWrites here (host needs Reads).
        let store = Store<AppAction, AppState, Void>(
            initial: AppState(rows: rows()), behavior: .identity, environment: ())
        let list: StoreProjection<ListAction, [Row]> = store.projection(
            .action(AppAction.prism.bulk).state(\AppState.rows))
        #expect(list.state.map(\.id) == [1, 2, 3])
    }

    @Test func optionalChildProjection() {
        // Optional child: base projection over an optional slice → Value? (the view unwraps with if let).
        let store = Store<AppAction, AppState, Void>(
            initial: AppState(only: Row(id: 5, name: "E")), behavior: .identity, environment: ())
        let opt: StoreProjection<RowAction, Row?> = store.projection(
            .action(AppAction.prism.only).state(\AppState.only))
        #expect(opt.state == Row(id: 5, name: "E"))
    }

    @Test func projectsByCustomIdAndDictionary() {
        let store = Store<AppAction, AppState, Void>(
            initial: AppState(rows: rows(), dict: ["k": Row(id: 7, name: "K")]), behavior: .identity, environment: ())
        let byName: StoreProjection<RowAction, Row?> = store.projection(
            .action(AppAction.prism.byName).state(\AppState.rows, id: \.name), element: "C")
        #expect(byName.state == Row(id: 3, name: "C"))
        let byKey: StoreProjection<RowAction, Row?> = store.projection(
            .action(AppAction.prism.dict).state(dictionary: \AppState.dict), element: "k")
        #expect(byKey.state == Row(id: 7, name: "K"))
    }
}
