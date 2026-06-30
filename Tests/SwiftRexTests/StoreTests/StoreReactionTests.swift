import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - Store driving a behavior's supervise axis (reconcile on every state change)

@Suite("Store + supervise")
@MainActor
struct StoreReactionTests {
    private struct S: Sendable, Equatable {
        var connected = false
        var outbox = 0
        var lastReceived = -1
    }

    private enum A: Sendable, Equatable {
        case connect
        case disconnect
        case setOutbox(Int)
        case received(Int)
    }

    private let reducerBehavior = Behavior<A, S, Void>.handle { action, _ in
        switch action {
        case .connect: .reduce { $0.connected = true }
        case .disconnect: .reduce { $0.connected = false }
        case .setOutbox(let v): .reduce { $0.outbox = v }
        case .received(let v): .reduce { $0.lastReceived = v }
        }
    }

    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test func channelLivesExactlyWhileTheStateConditionHolds() async {
        let opens = LockProtected(0)
        let cancels = LockProtected(0)
        let supervisor = Behavior<A, S, Void>.supervise { state in
            Supervision { _ in
                guard state.connected else { return [] }
                return [
                    Channel(id: "socket", broadcasting: .onChange(state.outbox)) { dispatch in
                        opens.mutate { $0 += 1 }
                        return ChannelHandler(
                            receive: { dispatch(.received($0)) },
                            cancel: { cancels.mutate { $0 += 1 } }
                        )
                    }
                ]
            }
        }
        let store = Store(initial: S(), behavior: .combine(reducerBehavior, supervisor))

        #expect(opens.value == 0)                      // initial state: not connected → no channel

        store.dispatch(.connect)                       // condition becomes true → channel opens
        await poll { opens.value == 1 }
        #expect(opens.value == 1)
        #expect(cancels.value == 0)

        store.dispatch(.setOutbox(7))                  // value changes → pipes 7 into the SAME channel
        await poll { store.state.lastReceived == 7 }
        #expect(store.state.lastReceived == 7)
        #expect(opens.value == 1)                      // not reopened
        #expect(cancels.value == 0)

        store.dispatch(.disconnect)                    // condition false → reconciler cancels it
        await poll { cancels.value == 1 }
        #expect(cancels.value == 1)
    }

    @Test func initialStateActivatesSuperviseWithoutADispatch() async {
        let supervisor = Behavior<A, S, Void>.supervise { state in
            Supervision { _ in
                state.connected ? [Channel(id: "ping") { dispatch in dispatch(.received(99)); return .cancelOnly {} }] : []
            }
        }
        // Start already connected — the initial reconcile fires the channel's body with no dispatch.
        let store = Store(initial: S(connected: true), behavior: .combine(reducerBehavior, supervisor))
        await poll { store.state.lastReceived == 99 }
        #expect(store.state.lastReceived == 99)
    }

    @Test func unchangedDesiredSetReopensNothing() async {
        let opens = LockProtected(0)
        let supervisor = Behavior<A, S, Void>.supervise { state in
            Supervision { _ in
                state.connected
                    ? [
                        Channel(id: "s", broadcasting: .onChange(state.outbox)) { _ in
                            opens.mutate { $0 += 1 }
                            return ChannelHandler(receive: { _ in }, cancel: {})
                        }
                    ]
                    : []
            }
        }
        let store = Store(initial: S(connected: true), behavior: .combine(reducerBehavior, supervisor))
        await poll { opens.value == 1 }

        // `setOutbox(0)` mutates (so reconcile runs), but outbox stays 0 → unchanged identities
        // → the engine diff produces zero ops, so the channel is never reopened.
        store.dispatch(.setOutbox(0))
        for _ in 0..<10 { await Task.yield() }
        #expect(opens.value == 1)
    }

    // MARK: - End-to-end: a real Store driving a LIFTED COLLECTION supervise

    private struct Item: Sendable, Equatable, Identifiable {
        let id: Int
        var connected: Bool
    }

    private enum ItemAction: Sendable, Equatable {
        case received(Int)
    }

    private struct AppState: Sendable {
        var items: [Item]
    }

    private enum AppAction: Sendable {
        case item(ElementAction<Int, ItemAction>)
        case addItem(Item)
        case removeItem(id: Int)
        case setConnected(id: Int, Bool)
    }

    private var itemPrism: Prism<AppAction, ElementAction<Int, ItemAction>> {
        Prism(
            preview: { if case .item(let e) = $0 { e } else { nil } },
            review: AppAction.item
        )
    }

    private var globalReducer: Behavior<AppAction, AppState, Void> {
        .reduce { action, state in
            switch action {
            case .addItem(let item): state.items.append(item)
            case .removeItem(let id): state.items.removeAll { $0.id == id }
            case let .setConnected(id, value):
                if let i = state.items.firstIndex(where: { $0.id == id }) { state.items[i].connected = value }
            case .item: break
            }
        }
    }

    /// The headline scenario: per-element sockets kept by state, lifted across a collection. Each
    /// element's channel opens under its own stamped id, and dropping one element's implying state
    /// cancels *exactly* that element's channel — the others are untouched and never reopened.
    @Test func collectionLiftOpensAndCancelsChannelsPerElement() async {
        let opens = LockProtected([Int]())
        let cancels = LockProtected([Int]())
        let itemBehavior = Behavior<ItemAction, Item, Void>.supervise { item in
            Supervision { _ in
                guard item.connected else { return [] }
                return [
                    Channel(id: "socket") { _ in
                        opens.mutate { $0.append(item.id) }
                        return .cancelOnly { cancels.mutate { $0.append(item.id) } }
                    }
                ]
            }
        }
        let lifted = itemBehavior.liftCollection(action: itemPrism, stateCollection: \AppState.items)
        let store = Store(
            initial: AppState(items: [Item(id: 1, connected: true), Item(id: 2, connected: true)]),
            behavior: .combine(globalReducer, lifted)
        )

        await poll { opens.value.count == 2 }
        #expect(opens.value.sorted() == [1, 2])      // both elements opened, each under its own stamped id
        #expect(cancels.value.isEmpty)

        store.dispatch(.setConnected(id: 1, false))   // only element 1 leaves the desired set
        await poll { cancels.value.contains(1) }
        #expect(cancels.value == [1])                 // exactly element 1 cancelled — element 2 untouched
        #expect(opens.value.sorted() == [1, 2])       // and element 2 was never reopened

        store.dispatch(.addItem(Item(id: 3, connected: true)))   // a new element opens its own channel
        await poll { opens.value.contains(3) }
        #expect(opens.value.sorted() == [1, 2, 3])

        store.dispatch(.removeItem(id: 2))            // dropping an element entirely cancels its channel
        await poll { cancels.value.contains(2) }
        #expect(cancels.value.sorted() == [1, 2])     // element 3 still alive
    }
}
