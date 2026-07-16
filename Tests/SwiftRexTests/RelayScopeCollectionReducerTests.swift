// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum RowAction: Sendable, Equatable { case bump }
private struct Row: Sendable, Equatable, Identifiable { let id: Int; var name: String; var taps = 0 }

private enum AppAction: Sendable, Equatable {
    case row(ElementAction<Int, RowAction>)
    case byName(ElementAction<String, RowAction>)
    case dict(ElementAction<String, RowAction>)
    case tickAll(RowAction)
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

@Suite("Relay.Scope collection — Reducer") @MainActor
struct RelayScopeCollectionReducerTests {
    private let bump = Reducer<RowAction, Row>.reduce { action, state in
        switch action {
        case .bump: state.taps += 1
        }
    }
    private func rows() -> [Row] { [Row(id: 1, name: "A"), Row(id: 2, name: "B"), Row(id: 3, name: "C")] }

    @Test func identifiableRoutesToOne() {
        let sut: Reducer<AppAction, AppState> = bump.liftCollection(.action(AppAction.prism.row).state(\AppState.rows))
        var state = AppState(rows: rows())
        sut.reduce(.row(ElementAction(2, action: .bump)))(&state)
        #expect(state.rows.map(\.taps) == [0, 1, 0])
    }

    @Test func customIdRoutesByName() {
        let sut: Reducer<AppAction, AppState> = bump.liftCollection(.action(AppAction.prism.byName).state(\AppState.rows, id: \.name))
        var state = AppState(rows: rows())
        sut.reduce(.byName(ElementAction("C", action: .bump)))(&state)
        #expect(state.rows.map(\.taps) == [0, 0, 1])
    }

    @Test func indexRoutesByPosition() {
        let sut: Reducer<AppAction, AppState> = bump.liftCollection(.action(AppAction.prism.row).state(indexed: \AppState.rows))
        var state = AppState(rows: rows())
        sut.reduce(.row(ElementAction(0, action: .bump)))(&state)
        #expect(state.rows.map(\.taps) == [1, 0, 0])
    }

    @Test func dictionaryRoutesByKey() {
        let sut: Reducer<AppAction, AppState> = bump.liftCollection(.action(AppAction.prism.dict).state(dictionary: \AppState.dict))
        var state = AppState(dict: ["x": Row(id: 9, name: "X"), "y": Row(id: 8, name: "Y")])
        sut.reduce(.dict(ElementAction("x", action: .bump)))(&state)
        #expect(state.dict["x"]?.taps == 1)
        #expect(state.dict["y"]?.taps == 0)
    }

    @Test func broadcastHitsEvery() {
        let sut: Reducer<AppAction, AppState> = bump.liftEach(
            .action(broadcast: AppAction.prism.tickAll, into: AppAction.prism.row).state(\AppState.rows))
        var state = AppState(rows: rows())
        sut.reduce(.tickAll(.bump))(&state)
        #expect(state.rows.allSatisfy { $0.taps == 1 })
    }
}
