// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum ChildAction: Sendable, Equatable { case tick }
private struct ChildState: Sendable, Equatable { var n = 0 }
private enum AppAction: Sendable, Equatable { case child(ChildAction) }
private struct AppState: Sendable, Equatable { var child = ChildState() }

@Suite("Relay.Scope builder")
@MainActor
struct RelayBuilderTests {
    private var childPrism: Prism<AppAction, ChildAction> {
        Prism(preview: { if case let .child(action) = $0 { action } else { nil } }, review: AppAction.child)
    }

    private func store(_ behavior: Behavior<AppAction, AppState, Void>) -> Store<AppAction, AppState, Void> {
        Store(initial: AppState(), behavior: behavior, environment: ())
    }

    @Test func projectsViaLeadingDotBuilderInline() {
        let base = store(.reduce { action, state in
            switch action {
            case .child(.tick): state.child.n += 1
            }
        })
        // Leading-dot: the host pins the generics, so the builder needs no annotation.
        let child = base.projection(.action(childPrism).state(\.child))
        child.dispatch(.tick)
        #expect(base.state.child.n == 1)
        #expect(child.state.n == 1)
    }

    @Test func liftsABehaviorViaADeclaredBuilder() {
        let childBehavior = Behavior<ChildAction, ChildState, Void>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
        // Bare declaration starts from `Relay.Empty`; full chain incl. environment for a behavior lift.
        let scope = Relay.Empty
            .action(childPrism)
            .state(\AppState.child)
            .environment { (_: Void) in () }
        let base = store(childBehavior.lift(scope))
        base.dispatch(.child(.tick))
        #expect(base.state.child.n == 1)
    }

    @Test func buildsViaClosurePairSugar() {
        let base = store(.reduce { action, state in
            switch action {
            case .child(.tick): state.child.n += 1
            }
        })
        // `.action(preview:review:)` → Prism, `.state(get:set:)` → ReadsWrites — the closure-pair sugar.
        let child = base.projection(
            .action(preview: { if case let .child(action) = $0 { action } else { nil } }, review: AppAction.child)
                .state(get: { $0.child }, set: { app, value in var copy = app; copy.child = value; return copy })
        )
        child.dispatch(.tick)
        #expect(base.state.child.n == 1)
        #expect(child.state.n == 1)
    }
}
