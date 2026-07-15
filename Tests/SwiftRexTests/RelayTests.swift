// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum LocalAction: Sendable, Equatable { case tick }
private struct LocalState: Sendable, Equatable { var n = 0 }
private enum GlobalAction: Sendable, Equatable { case local(LocalAction) }
private struct GlobalState: Sendable, Equatable { var local = LocalState() }

@Suite("Relay.Scope")
@MainActor
struct RelayScopeTests {
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

    @Test func projectsAStoreThroughARichScope() {
        // A duplex Prism + total ReadsWrites subsumes what projection needs — EmbedsProtocol + ReadsProtocol.
        // The env lane defaults to `.Absent` via the 2-arg init.
        let scope = Relay.Scope(
            action: Relay.ActionAxis.Prism<GlobalAction, LocalAction>(
                Prism(preview: { if case let .local(value) = $0 { value } else { nil } }, review: GlobalAction.local)
            ),
            state: Relay.StateAxis.ReadsWrites<GlobalState, LocalState>(\.local)
        )
        let store = makeStore()
        let local = store.projection(scope) // StoreProjection<LocalAction, LocalState>

        local.dispatch(.tick)
        #expect(store.state.local.n == 1) // Embeds review lifted the local action; the reducer ran
        #expect(local.state.n == 1) // Reads get projected the global state
    }

    @Test func projectsThroughTheMinimalLanes() {
        // The minimum a projection needs — embed-only action + read-only state, from bare closures/keypaths.
        let scope = Relay.Scope(
            action: Relay.ActionAxis.Embeds<GlobalAction, LocalAction>(GlobalAction.local),
            state: Relay.StateAxis.Reads<GlobalState, LocalState>(\.local)
        )
        let store = makeStore()
        let local = store.projection(scope)

        local.dispatch(.tick)
        #expect(store.state.local.n == 1)
        #expect(local.state.n == 1)
    }
}
