// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

private enum LocalAction: Sendable, Equatable { case tick }
private struct LocalState: Sendable, Equatable { var n = 0 }
private enum GlobalAction: Sendable, Equatable { case local(LocalAction) }
private struct GlobalState: Sendable, Equatable { var local = LocalState() }

private enum GlobalDomain: Transceiver { typealias Action = GlobalAction; typealias State = GlobalState }
private enum LocalDomain: Transceiver { typealias Action = LocalAction; typealias State = LocalState }

@Suite("Relay")
@MainActor
struct RelayTests {
    private func makeStore() -> Store<GlobalAction, GlobalState, Void> {
        Store(
            initial: GlobalState(),
            behavior: Behavior<GlobalAction, GlobalState, Void>.reduce { action, state in
                switch action {
                case .local(.tick): state.local.n += 1
                }
            },
            environment: ()
        )
    }

    @Test func projectsAStoreThroughARelay() {
        let relay = Relay<GlobalDomain, LocalDomain>(
            uplink: GlobalAction.local, // (LocalAction) -> GlobalAction
            downlink: { $0.local } // (GlobalState) -> LocalState
        )
        let store = makeStore()
        let local = store.projection(relay) // StoreProjection<LocalAction, LocalState>

        local.dispatch(.tick)
        #expect(store.state.local.n == 1) // uplink embedded the local action; the reducer ran
        #expect(local.state.n == 1) // downlink projected the global state
    }

    @Test func relaysCompose() {
        let outer = Relay<GlobalDomain, LocalDomain>(uplink: GlobalAction.local, downlink: { $0.local })
        let identity = Relay<LocalDomain, LocalDomain>(uplink: { $0 }, downlink: { $0 })
        let composed = outer.then(identity) // Relay<GlobalDomain, LocalDomain> — dimap composition

        let store = makeStore()
        store.projection(composed).dispatch(.tick)
        #expect(store.state.local.n == 1)
    }
}
