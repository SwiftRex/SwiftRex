// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum ChildAction: Sendable, Equatable { case tick }
private struct ChildState: Sendable, Equatable { var n = 0 }
private struct ChildEnv: Sendable {}

private enum AppAction: Sendable, Equatable { case child(ChildAction) }
private struct AppState: Sendable, Equatable { var child = ChildState() }
private struct AppEnv: Sendable { let child = ChildEnv() }

// The pivot Rig — names the app triad once so `ScopeOf<AppFeature>` can root bare optics against it.
private enum AppFeature: Rig {
    typealias Action = AppAction
    typealias State = AppState
    typealias Environment = AppEnv
}

@Suite("Relay ScopeOf<Global> pivot builder")
@MainActor
struct RelayScopeOfTests {
    private var childPrism: Prism<AppAction, ChildAction> {
        Prism(preview: { if case let .child(action) = $0 { action } else { nil } }, review: AppAction.child)
    }

    @Test func pivotRootsBareOpticsAndLifts() {
        let childBehavior = Behavior<ChildAction, ChildState, ChildEnv>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }

        // The whole point: state key path is BARE (`\.child`, rooted at AppFeature.State — no `\AppState.`),
        // and the env closure's parameter is INFERRED as AppFeature.Environment (no `(e: AppEnv) in`).
        let pivot = Relay.ScopeOf<AppFeature>
            .action(childPrism)
            .state(\.child)
            .environment { $0.child }

        let lifted: Behavior<AppAction, AppState, AppEnv> = childBehavior.lift(pivot.scope)
        let store = Store(initial: AppState(), behavior: lifted, environment: AppEnv())
        store.dispatch(.child(.tick))
        #expect(store.state.child.n == 1)
    }

    @Test func pivotBuildsInAnyAxisOrder() {
        // Entry can start from any axis; the pivot carries AppFeature through so later bare optics still root.
        let a = Relay.ScopeOf<AppFeature>.state(\.child).action(childPrism).environment { $0.child }
        let b = Relay.ScopeOf<AppFeature>.environment { $0.child }.action(childPrism).state(\.child)
        // Both terminate into the same lane bundle shape.
        #expect(type(of: a.scope) == type(of: b.scope))
    }
}
