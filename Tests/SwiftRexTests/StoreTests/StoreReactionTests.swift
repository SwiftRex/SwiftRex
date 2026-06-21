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
            Keep { _ in
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
            Keep { _ in
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
            Keep { _ in
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
}
