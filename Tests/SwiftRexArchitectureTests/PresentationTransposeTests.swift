// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
import SwiftRexSwiftUI
import Testing

private enum SeqChildAction: Sendable, Equatable { case bump; case setName(String) }
private struct SeqChild: Sendable, Equatable { var n = 0; var name = "" }
private enum SeqAppAction: Sendable, Equatable { case child(SeqChildAction) }
extension SeqAppAction: Prismatic {
    struct Prisms: Sendable {
        let child = Prism<SeqAppAction, SeqChildAction>(
            preview: { if case let .child(v) = $0 { v } else { nil } }, review: SeqAppAction.child)
    }
    static let prism = Prisms()
}
extension SeqChildAction: Prismatic {
    struct Prisms: Sendable {
        let setName = Prism<SeqChildAction, String>(
            preview: { if case let .setName(v) = $0 { v } else { nil } }, review: SeqChildAction.setName)
    }
    static let prism = Prisms()
}
private struct SeqApp: Sendable, Equatable { var detail: Presentation<SeqChild>; var rows: [SeqRow] = [] }
private struct SeqRow: Sendable, Equatable, Identifiable { let id: Int; var name: String }
private enum SeqRowAction: Sendable, Equatable { case setName(String) }
extension SeqRowAction: Prismatic {
    struct Prisms: Sendable {
        let setName = Prism<SeqRowAction, String>(
            preview: { if case let .setName(v) = $0 { v } else { nil } }, review: SeqRowAction.setName)
    }
    static let prism = Prisms()
}
private enum ListAppAction: Sendable, Equatable { case row(ElementAction<Int, SeqRowAction>) }
extension ListAppAction: Prismatic {
    struct Prisms: Sendable {
        let row = Prism<ListAppAction, ElementAction<Int, SeqRowAction>>(
            preview: { if case let .row(v) = $0 { v } else { nil } }, review: ListAppAction.row)
    }
    static let prism = Prisms()
}
private struct ListApp: Sendable, Equatable { var rows: [SeqRow] = [] }

@Suite("StoreProjection.transpose — Presentation<T>") @MainActor
struct PresentationTransposeTests {
    private func transposed(_ detail: Presentation<SeqChild>) -> SeqChild? {
        Store<SeqAppAction, SeqApp, Void>(initial: SeqApp(detail: detail), behavior: .identity, environment: ())
            .projection(.action(SeqAppAction.prism.child).state(\SeqApp.detail))
            .transpose()?.state
    }

    @Test func presentedSwapsToStore() {
        #expect(transposed(.presented(SeqChild(n: 3))) == SeqChild(n: 3))
    }

    @Test func dismissingStillHasStore() {
        // The value persists through the dismiss animation — a modeled stage, not a snapshot.
        #expect(transposed(.dismissing(last: SeqChild(n: 7))) == SeqChild(n: 7))
    }

    @Test func dismissedSwapsToNil() {
        #expect(transposed(.dismissed) == nil)
    }
}

@Suite("Relay.Scope two-way binding") @MainActor
struct RelayScopeBindingTests {
    // #2 — scope-vocabulary binding: Action.L == State.L (shared value type).
    @Test func scopeBindingReadsAndDispatches() {
        let reducer = Behavior<SeqChildAction, SeqChild, Void>.reduce { action, state in
            if case let .setName(v) = action { state.name = v }
        }
        let store = Store<SeqChildAction, SeqChild, Void>(initial: SeqChild(name: "old"), behavior: reducer, environment: ())
        let binding = store.binding(.state(\SeqChild.name), dispatch: .action(SeqChildAction.prism.setName))
        #expect(binding.wrappedValue == "old")   // get reads state
        binding.wrappedValue = "new"             // set dispatches .setName → reducer writes
        #expect(store.state.name == "new")
    }

    // #1 — element-field binding composes for free through transpose(): the unwrapped element store
    // takes the existing keypath binding.
    @Test func elementFieldBindingViaTranspose() {
        let rowBehavior = Behavior<SeqRowAction, SeqRow, Void>.reduce { action, state in
            if case let .setName(v) = action { state.name = v }
        }
        let store = Store<ListAppAction, ListApp, Void>(
            initial: ListApp(rows: [SeqRow(id: 1, name: "A"), SeqRow(id: 2, name: "B")]),
            behavior: rowBehavior.liftCollection(.action(ListAppAction.prism.row).state(\ListApp.rows).environment { (v: Void) in v }),
            environment: ())
        // project element 2 → transpose to an unwrapped Store<SeqRowAction, SeqRow> → bind its \.name field
        if let rowStore = store.projection(.action(ListAppAction.prism.row).state(\ListApp.rows), element: 2).transpose() {
            let binding = rowStore.binding(.state(\.name), dispatch: .action(review: SeqRowAction.setName))
            #expect(binding.wrappedValue == "B")
            binding.wrappedValue = "B2"
            #expect(store.state.rows.first(where: { $0.id == 2 })?.name == "B2")
            #expect(store.state.rows.first(where: { $0.id == 1 })?.name == "A")
        } else {
            Issue.record("expected element 2 present")
        }
    }
}
#endif
