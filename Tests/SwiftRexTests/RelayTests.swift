// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum LocalAction: Sendable, Equatable { case tick }
private struct LocalState: Sendable, Equatable { var n = 0 }
private enum GlobalAction: Sendable, Equatable { case local(LocalAction) }
private struct GlobalState: Sendable, Equatable { var local = LocalState() }

// Hand-rolled `Prismatic` (the shape `@Prisms` generates) so `\.local` is a usable `PrismKeyPath`
// without depending on the macro module.
extension GlobalAction: Prismatic {
    struct Prisms: Sendable {
        let local = Prism<GlobalAction, LocalAction>(
            preview: { if case let .local(value) = $0 { value } else { nil } },
            review: GlobalAction.local
        )
    }

    static let prism = Prisms()
}

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
            action: GlobalAction.local, // (LocalAction) -> GlobalAction
            state: { $0.local } // (GlobalState) -> LocalState
        )
        let store = makeStore()
        let local = store.projection(relay) // StoreProjection<LocalAction, LocalState>

        local.dispatch(.tick)
        #expect(store.state.local.n == 1) // uplink embedded the local action; the reducer ran
        #expect(local.state.n == 1) // downlink projected the global state
    }

    @Test func projectsViaPureOptics() {
        let relay = Relay<GlobalDomain, LocalDomain>(
            action: Prism(
                preview: { if case let .local(value) = $0 { value } else { nil } },
                review: GlobalAction.local
            ),
            state: Lens(get: \.local, set: { whole, part in var copy = whole; copy.local = part; return copy })
        )
        let store = makeStore()
        let local = store.projection(relay)

        local.dispatch(.tick)
        #expect(store.state.local.n == 1)
        #expect(local.state.n == 1)
    }

    @Test func projectsViaKeyPaths() {
        let relay = Relay<GlobalDomain, LocalDomain>(action: \.local, state: \.local)
        let store = makeStore()
        let local = store.projection(relay)

        local.dispatch(.tick)
        #expect(store.state.local.n == 1)
        #expect(local.state.n == 1)
    }

    @Test func relaysCompose() {
        let outer = Relay<GlobalDomain, LocalDomain>(action: GlobalAction.local, state: { $0.local })
        let identity = Relay<LocalDomain, LocalDomain>(action: { $0 }, state: { $0 })
        let composed = outer.then(identity) // Relay<GlobalDomain, LocalDomain> — dimap composition

        let store = makeStore()
        store.projection(composed).dispatch(.tick)
        #expect(store.state.local.n == 1)
    }
}
