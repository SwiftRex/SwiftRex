// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum RowAction: Sendable, Equatable { case bump }
private struct Row: Sendable, Equatable, Identifiable { let id: Int; var name: String; var taps = 0 }

private enum AppAction: Sendable, Equatable {
    case row(ElementAction<Int, RowAction>)         // Identifiable / index (id == Int)
    case byName(ElementAction<String, RowAction>)   // custom-id (\.name)
    case dict(ElementAction<String, RowAction>)     // dictionary (Key == String)
    case tickAll(RowAction)                         // broadcast inbound
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let row = Prism<AppAction, ElementAction<Int, RowAction>>(
            preview: { if case let .row(v) = $0 { v } else { nil } }, review: AppAction.row)
        let byName = Prism<AppAction, ElementAction<String, RowAction>>(
            preview: { if case let .byName(v) = $0 { v } else { nil } }, review: AppAction.byName)
        let dict = Prism<AppAction, ElementAction<String, RowAction>>(
            preview: { if case let .dict(v) = $0 { v } else { nil } }, review: AppAction.dict)
        let tickAll = Prism<AppAction, RowAction>(
            preview: { if case let .tickAll(v) = $0 { v } else { nil } }, review: AppAction.tickAll)
    }
    static let prism = Prisms()
}

private struct AppState: Sendable, Equatable {
    var rows: [Row] = []
    var dict: [String: Row] = [:]
}

private func rowBehavior() -> Behavior<RowAction, Row, Void> {
    .reduce { action, state in
        switch action {
        case .bump: state.taps += 1
        }
    }
}

@Suite("Relay.Scope collection — Behavior") @MainActor
struct RelayScopeCollectionBehaviorTests {
    private func rows() -> [Row] { [Row(id: 1, name: "A"), Row(id: 2, name: "B"), Row(id: 3, name: "C")] }

    private func store(_ behavior: Behavior<AppAction, AppState, Void>, _ state: AppState) -> Store<AppAction, AppState, Void> {
        Store<AppAction, AppState, Void>(initial: state, behavior: behavior, environment: ())
    }

    @Test func identifiableKeyPathRoutesToOne() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(AppAction.prism.row).state(\AppState.rows).environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.row(ElementAction(2, action: .bump)))
        #expect(s.state.rows.map(\.taps) == [0, 1, 0])
    }

    @Test func identifiableLensRoutesToOne() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(AppAction.prism.row).state(lens(\AppState.rows)).environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.row(ElementAction(3, action: .bump)))
        #expect(s.state.rows.map(\.taps) == [0, 0, 1])
    }

    @Test func customIdRoutesByKeyPath() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(AppAction.prism.byName).state(\AppState.rows, id: \.name).environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.byName(ElementAction("B", action: .bump)))
        #expect(s.state.rows.map(\.taps) == [0, 1, 0])
    }

    @Test func indexRoutesByPosition() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(AppAction.prism.row).state(indexed: \AppState.rows).environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.row(ElementAction(0, action: .bump)))   // position 0
        #expect(s.state.rows.map(\.taps) == [1, 0, 0])
    }

    @Test func dictionaryRoutesByKey() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(AppAction.prism.dict).state(dictionary: \AppState.dict).environment { (v: Void) in v })
        let s = store(lifted, AppState(dict: ["x": Row(id: 9, name: "X"), "y": Row(id: 8, name: "Y")]))
        s.dispatch(.dict(ElementAction("y", action: .bump)))
        #expect(s.state.dict["y"]?.taps == 1)
        #expect(s.state.dict["x"]?.taps == 0)
    }

    @Test func doubleClosureMacroFree() {
        // No reliance on the prism — raw closures a macro-free user would write.
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftCollection(
            .action(
                preview: { (g: AppAction) -> (id: Int, action: RowAction)? in
                    if case let .row(ea) = g { (id: ea.id, action: ea.action) } else { nil }
                },
                review: { (id: Int, a: RowAction) in AppAction.row(ElementAction(id, action: a)) }
            )
            .state(\AppState.rows)
            .environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.row(ElementAction(1, action: .bump)))
        #expect(s.state.rows.map(\.taps) == [1, 0, 0])
    }

    @Test func broadcastPrismIntoHitsEvery() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftEach(
            .action(broadcast: AppAction.prism.tickAll, into: AppAction.prism.row)
                .state(\AppState.rows)
                .environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.tickAll(.bump))
        #expect(s.state.rows.allSatisfy { $0.taps == 1 })
    }

    @Test func broadcastRawHitsEvery() {
        let lifted: Behavior<AppAction, AppState, Void> = rowBehavior().liftEach(
            .action(
                broadcast: { (g: AppAction) -> RowAction? in if case let .tickAll(a) = g { a } else { nil } },
                embed: { (id: Int, a: RowAction) in AppAction.row(ElementAction(id, action: a)) }
            )
            .state(\AppState.rows)
            .environment { (v: Void) in v })
        let s = store(lifted, AppState(rows: rows()))
        s.dispatch(.tickAll(.bump))
        #expect(s.state.rows.allSatisfy { $0.taps == 1 })
    }
}
