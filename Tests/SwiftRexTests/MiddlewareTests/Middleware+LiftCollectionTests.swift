import CoreFP
import DataStructure
import Foundation
@testable import SwiftRex
import Testing

@Suite @MainActor
struct MiddlewareLiftCollectionTests {
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

    private struct AppState: Sendable {
        var items: [Item] = []
        var lookup: [String: Item] = [:]
    }

    private enum AppAction: Sendable {
        case item(ElementAction<UUID, LocalAction>)
        case keyed(ElementAction<String, LocalAction>)
        case unrelated
    }

    private let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // On `.bump`, schedule a `.replacing(id: "fetch")` effect emitting `.done`. The shared inner
    // id "fetch" is what `liftCollection` must scope per element.
    private let elementMiddleware = Middleware<LocalAction, Item, Void> { action, _ in
        switch action {
        case .bump:
            Reader { _ in .just(.done, scheduling: .replacing(id: "fetch")) }
        case .done:
            Reader { _ in .empty }
        }
    }

    private let itemPrism = Prism<AppAction, ElementAction<UUID, LocalAction>>(
        preview: { if case .item(let ea) = $0 { ea } else { nil } },
        review: { .item($0) }
    )

    // MARK: - Helpers

    private func effect(
        _ sut: Middleware<AppAction, AppState, Void>,
        action: AppAction,
        state: AppState
    ) -> Effect<AppAction> {
        sut.handle(action, PreReducerContext(source: Self.anySource, getter: { state }))
            .runReader(PostReducerContext(environment: (), getter: { state }))
    }

    // MARK: - Output action re-embedding

    @Test func emittedActionIsReEmbeddedAtSameElement() {
        let sut = elementMiddleware.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let state = AppState(items: [Item(id: id1, value: 0)])
        let received = LockProtected([AppAction]())
        subscribeAll(effect(sut, action: .item(ElementAction(id1, action: .bump)), state: state)) { d in
            received.mutate { $0.append(d.action) }
        }
        guard case .item(let ea) = received.value.first else {
            Issue.record("Expected a re-embedded .item action")
            return
        }
        #expect(ea.id == id1)
        #expect(ea.action == .done)
    }

    @Test func unmatchedActionIsNoOp() {
        let sut = elementMiddleware.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let state = AppState(items: [Item(id: id1, value: 5)])
        #expect(effect(sut, action: .unrelated, state: state).components.isEmpty)
    }

    // MARK: - Per-element effect-scheduling scope

    @Test func schedulingIdIsScopedPerElement() {
        let sut = elementMiddleware.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let state = AppState(items: [Item(id: id1, value: 0), Item(id: id2, value: 0)])

        let effA = effect(sut, action: .item(ElementAction(id1, action: .bump)), state: state)
        let effB = effect(sut, action: .item(ElementAction(id2, action: .bump)), state: state)

        let expectedA = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable(id1), inner: AnyHashableSendable("fetch"))
        )
        let expectedB = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable(id2), inner: AnyHashableSendable("fetch"))
        )

        guard case .replacing(let idA) = effA.components.first?.scheduling,
              case .replacing(let idB) = effB.components.first?.scheduling else {
            Issue.record("Expected .replacing scheduling on both elements")
            return
        }
        #expect(idA == expectedA)
        #expect(idB == expectedB)
        #expect(idA != idB)
    }

    // MARK: - Dictionary key-based

    @Test func dictionaryScopesScheduling() {
        let prism = Prism<AppAction, ElementAction<String, LocalAction>>(
            preview: { if case .keyed(let ea) = $0 { ea } else { nil } },
            review: { .keyed($0) }
        )
        let sut = elementMiddleware.liftCollection(action: prism, stateDictionary: \AppState.lookup)
        let state = AppState(lookup: ["x": Item(id: id1, value: 1)])
        let eff = effect(sut, action: .keyed(ElementAction("x", action: .bump)), state: state)
        let expected = AnyHashableSendable(
            ElementScopedID(element: AnyHashableSendable("x"), inner: AnyHashableSendable("fetch"))
        )
        guard case .replacing(let id) = eff.components.first?.scheduling else {
            Issue.record("Expected .replacing scheduling")
            return
        }
        #expect(id == expected)
    }
}
