// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
import Foundation
@testable import SwiftRex
import Testing

@Suite @MainActor
struct BehaviorLiftCollectionTests {
    private static let anySource = ActionSource(file: #file, function: #function, line: #line)

    // MARK: - Domain

    private enum LocalAction: Equatable, Sendable {
        case bump
        case done
    }

    private struct Item: Identifiable, Sendable {
        let id: UUID
        var value: Int
    }

    private struct Named: Sendable {
        let tag: String
        var value: Int
    }

    private struct AppState: Sendable {
        var items: [Item] = []
        var named: [Named] = []
        var lookup: [String: Item] = [:]
    }

    private enum AppAction: Sendable {
        case item(ElementAction<UUID, LocalAction>)
        case named(ElementAction<String, LocalAction>)
        case keyed(ElementAction<String, LocalAction>)
        case unrelated
    }

    private let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // A behavior that mutates its element on `.bump` and schedules a `.replacing(id: "fetch")`
    // effect emitting `.done`. The shared inner id "fetch" is what `liftCollection` must scope
    // per element.
    private let elementBehavior = Behavior<LocalAction, Item, Void> { action, _ in
        switch action {
        case .bump:
            .reduce { $0.value += 1 }
                .produce { _ in .just(.done, scheduling: .replacing(id: "fetch")) }
        case .done:
            .doNothing
        }
    }

    private let itemPrism = Prism<AppAction, ElementAction<UUID, LocalAction>>(
        preview: { if case let .item(ea) = $0 { ea } else { nil } },
        review: { .item($0) }
    )

    // MARK: - Helpers

    private func consequence(
        _ sut: Behavior<AppAction, AppState, Void>,
        action: AppAction,
        state: AppState
    ) -> Reaction<AppState, Void, AppAction> {
        sut.handle(action, PreReducerContext(source: Self.anySource, getter: { state }))
    }

    // MARK: - Identifiable mutation

    @Test func identifiableMutatesTargetedElement() {
        let sut = elementBehavior.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        var state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 10)])
        consequence(sut, action: .item(ElementAction(id1, action: .bump)), state: state)
            .mutation.runEndoMut(&state)
        #expect(state.items[0].value == 1)
        #expect(state.items[1].value == 10)
    }

    @Test func unmatchedActionIsNoOp() {
        let sut = elementBehavior.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        var state = AppState(items: [Item(id: id1, value: 5)])
        let c = consequence(sut, action: .unrelated, state: state)
        c.mutation.runEndoMut(&state)
        #expect(state.items[0].value == 5)
        #expect(c.produce(PostReducerContext(environment: (), getter: { state })).components.isEmpty)
    }

    // MARK: - Output action re-embedding

    @Test func emittedActionIsReEmbeddedAtSameElement() {
        let sut = elementBehavior.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let state = AppState(items: [Item(id: id1, value: 0)])
        let c = consequence(sut, action: .item(ElementAction(id1, action: .bump)), state: state)
        let effect = c.produce(PostReducerContext(environment: (), getter: { state }))
        let received = LockProtected([AppAction]())
        subscribeAll(effect) { d in received.mutate { $0.append(d.action) } }
        guard case let .item(ea) = received.value.first else {
            Issue.record("Expected a re-embedded .item action")
            return
        }
        #expect(ea.id == id1)
        #expect(ea.action == .done)
    }

    // MARK: - Per-element effect-scheduling scope

    @Test func schedulingIdIsScopedPerElement() {
        let sut = elementBehavior.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 0)])

        let effA = consequence(sut, action: .item(ElementAction(id1, action: .bump)), state: state)
            .produce(PostReducerContext(environment: (), getter: { state }))
        let effB = consequence(sut, action: .item(ElementAction(id2, action: .bump)), state: state)
            .produce(PostReducerContext(environment: (), getter: { state }))

        let expectedA = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable(id1), inner: AnyHashableSendable("fetch"))
        )
        let expectedB = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable(id2), inner: AnyHashableSendable("fetch"))
        )

        let idA = effA.components.first?.scheduling.id
        let idB = effB.components.first?.scheduling.id
        #expect(idA == expectedA)
        #expect(idB == expectedB)
        #expect(idA != idB) // same inner "fetch", different element → independent
    }

    // MARK: - Custom Hashable identifier

    @Test func customIdentifierMutatesAndScopes() {
        let namedBehavior = Behavior<LocalAction, Named, Void> { action, _ in
            switch action {
            case .bump:
                .reduce { $0.value += 1 }
                    .produce { _ in .just(.done, scheduling: .replacing(id: "fetch")) }
            case .done:
                .doNothing
            }
        }
        let prism = Prism<AppAction, ElementAction<String, LocalAction>>(
            preview: { if case let .named(ea) = $0 { ea } else { nil } },
            review: { .named($0) }
        )
        let sut = namedBehavior.liftCollection(
            action: prism,
            stateCollection: \AppState.named,
            identifier: { $0.tag }
        )
        var state = AppState(named: [Named(tag: "a", value: 0), Named(tag: "b", value: 5)])
        let c = consequence(sut, action: .named(ElementAction("b", action: .bump)), state: state)
        c.mutation.runEndoMut(&state)
        #expect(state.named[0].value == 0)
        #expect(state.named[1].value == 6)

        let eff = c.produce(PostReducerContext(environment: (), getter: { state }))
        let expected = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable("b"), inner: AnyHashableSendable("fetch"))
        )
        #expect(eff.components.first?.scheduling.id == expected)
    }

    // MARK: - Dictionary key-based

    @Test func dictionaryMutatesAndScopes() {
        let prism = Prism<AppAction, ElementAction<String, LocalAction>>(
            preview: { if case let .keyed(ea) = $0 { ea } else { nil } },
            review: { .keyed($0) }
        )
        let sut = elementBehavior.liftCollection(action: prism, stateDictionary: \AppState.lookup)
        var state = AppState(lookup: ["x": Item(id: id1, value: 1)])
        let c = consequence(sut, action: .keyed(ElementAction("x", action: .bump)), state: state)
        c.mutation.runEndoMut(&state)
        #expect(state.lookup["x"]?.value == 2)

        let eff = c.produce(PostReducerContext(environment: (), getter: { state }))
        let expected = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable("x"), inner: AnyHashableSendable("fetch"))
        )
        #expect(eff.components.first?.scheduling.id == expected)
    }
}
