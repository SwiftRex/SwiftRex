// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
import Foundation
@testable import SwiftRex
import Testing

@Suite("Relay.Scope collection — Middleware") @MainActor
struct RelayScopeCollectionMiddlewareTests {
    private static let anySource = ActionSource(file: #file, function: #function, line: #line)

    private enum RowAction: Equatable, Sendable { case bump, done }
    private struct Row: Identifiable, Sendable { let id: Int; var value = 0 }
    private struct AppState: Sendable { var rows: [Row] = [] }
    private enum AppAction: Sendable {
        case row(ElementAction<Int, RowAction>)
        case tickAll(RowAction)
        case unrelated
    }

    private static let prism = Prism<AppAction, ElementAction<Int, RowAction>>(
        preview: { if case let .row(ea) = $0 { ea } else { nil } }, review: { .row($0) })
    private static let tickAll = Prism<AppAction, RowAction>(
        preview: { if case let .tickAll(a) = $0 { a } else { nil } }, review: { .tickAll($0) })

    // On `.bump`, schedule an effect with a shared inner id "fetch" — the collection host must scope it per element.
    private let elementMiddleware = Middleware<RowAction, Row, Void> { action, _ in
        switch action {
        case .bump: Reader { _ in .just(.done, scheduling: .replacing(id: "fetch")) }
        case .done: Reader { _ in .empty }
        }
    }

    private func effect(_ sut: Middleware<AppAction, AppState, Void>, action: AppAction, state: AppState) -> Effect<AppAction> {
        sut.handle(action, PreReducerContext(source: Self.anySource, getter: { state }))
            .runReader(PostReducerContext(environment: (), getter: { state }))
    }

    @Test func liftCollectionReEmbedsAtSameElement() {
        let sut = elementMiddleware.liftCollection(
            .action(Self.prism).state(\AppState.rows).environment { (v: Void) in v })
        let state = AppState(rows: [Row(id: 1), Row(id: 2)])
        let received = LockProtected([AppAction]())
        subscribeAll(effect(sut, action: .row(ElementAction(2, action: .bump)), state: state)) { d in
            received.mutate { $0.append(d.action) }
        }
        guard case let .row(ea) = received.value.first else {
            Issue.record("expected a re-embedded .row action")
            return
        }
        #expect(ea.id == 2)
        #expect(ea.action == .done)
    }

    @Test func liftCollectionScopesSchedulingPerElement() {
        let sut = elementMiddleware.liftCollection(
            .action(Self.prism).state(\AppState.rows).environment { (v: Void) in v })
        let state = AppState(rows: [Row(id: 1), Row(id: 2)])
        let idA = effect(sut, action: .row(ElementAction(1, action: .bump)), state: state).components.first?.scheduling.id
        let idB = effect(sut, action: .row(ElementAction(2, action: .bump)), state: state).components.first?.scheduling.id
        #expect(idA == AnyHashableSendable(ElementScopedID(element: AnyHashableSendable(1), inner: AnyHashableSendable("fetch"))))
        #expect(idB == AnyHashableSendable(ElementScopedID(element: AnyHashableSendable(2), inner: AnyHashableSendable("fetch"))))
        #expect(idA != idB)
    }

    @Test func unmatchedIsNoOp() {
        let sut = elementMiddleware.liftCollection(
            .action(Self.prism).state(\AppState.rows).environment { (v: Void) in v })
        #expect(effect(sut, action: .unrelated, state: AppState(rows: [Row(id: 1)])).components.isEmpty)
    }

    @Test func liftEachReEmbedsEachElement() {
        let sut = elementMiddleware.liftEach(
            .action(broadcast: Self.tickAll, into: Self.prism).state(\AppState.rows).environment { (v: Void) in v })
        let state = AppState(rows: [Row(id: 1), Row(id: 2)])
        let received = LockProtected(Set<Int>())
        subscribeAll(effect(sut, action: .tickAll(.bump), state: state)) { d in
            if case let .row(ea) = d.action { received.mutate { $0.insert(ea.id) } }
        }
        #expect(received.value == [1, 2])
    }
}
