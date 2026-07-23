// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum ChildAction: Sendable, Equatable { case tick }
private struct ChildState: Sendable, Equatable { var n = 0 }
private enum AppAction: Sendable, Equatable { case child(ChildAction) }
private struct AppState: Sendable, Equatable { var child = ChildState() }

private enum TestApp: Rig {
    typealias Action = AppAction
    typealias State = AppState
    typealias Environment = Void
}

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
        // Bare declaration: `ScopeOf<TestApp>` is the concrete all-Identity entry — its statics pin the
        // Rig's globals; full chain incl. environment for a behavior lift.
        let scope = ScopeOf<TestApp>
            .action(childPrism)
            .state(\.child)
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

    @Test func buildsViaSingleClosureSugar() {
        let base = store(.reduce { action, state in
            switch action {
            case .child(.tick): state.child.n += 1
            }
        })
        // Minimum closures: embeds-only action (the enum case ctor) + reads-only state → a projection.
        let child = base.projection(.action(review: AppAction.child).state { $0.child })
        child.dispatch(.tick)
        #expect(base.state.child.n == 1)
        #expect(child.state.n == 1)
    }

    @Test func liftsReducerViaExtractsPreviewSugar() {
        let childReducer = Reducer<ChildAction, ChildState>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
        // Extract-only action (single `preview`) + `get:set:` state → a reducer lift.
        // The result is annotated so the reducer-lift's global types are pinned (leading-dot infers off it).
        let lifted: Reducer<AppAction, AppState> = childReducer.lift(
            .action(preview: { (global: AppAction) in if case let .child(action) = global { action } else { nil } })
                .state(get: { $0.child }, set: { app, value in var copy = app; copy.child = value; return copy })
        )
        var state = AppState()
        lifted.reduce(.child(.tick))(&state)
        #expect(state.child.n == 1)
    }

    @Test func declaredPartialScopeServesReducerAndProjection() {
        // A declared pair leaves env un-set → concretely `Identity<Void>`, NEVER `Absurd` (a `ScopeOf`
        // chain can't produce a sealed axis — `Absurd` is host vocabulary, filled only in inline chains).
        // The env-ignoring hosts take it through their generic-environment overloads, so ONE declared
        // value drives the reducer lift AND the store projection.
        let pair = ScopeOf<TestApp>.action(childPrism).state(\.child)

        let childReducer = Reducer<ChildAction, ChildState>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
        let lifted: Reducer<AppAction, AppState> = childReducer.lift(pair)
        var state = AppState()
        lifted.reduce(.child(.tick))(&state)
        #expect(state.child.n == 1)

        let base = store(.reduce { action, state in
            switch action {
            case .child(.tick): state.child.n += 1
            }
        })
        let child = base.projection(pair)
        child.dispatch(.tick)
        #expect(base.state.child.n == 1)
        #expect(child.state.n == 1)
    }

    @Test func declaredDuplexScopeServesEveryHost() {
        // ONE full declared scope — duplex action, total state, REAL env narrow. `Behavior.lift` consumes
        // all three lanes; `Reducer.lift` and `projection` accept the same value through their
        // generic-environment overloads, simply ignoring the `Narrows` lane.
        let full = ScopeOf<TestApp>
            .action(childPrism)
            .state(\.child)
            .environment { (_: Void) in () }

        let childBehavior = Behavior<ChildAction, ChildState, Void>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
        let viaBehavior = store(childBehavior.lift(full))
        viaBehavior.dispatch(.child(.tick))
        #expect(viaBehavior.state.child.n == 1)

        let childReducer = Reducer<ChildAction, ChildState>.reduce { action, state in
            switch action {
            case .tick: state.n += 1
            }
        }
        let lifted: Reducer<AppAction, AppState> = childReducer.lift(full)
        var state = AppState()
        lifted.reduce(.child(.tick))(&state)
        #expect(state.child.n == 1)

        let base = store(.reduce { action, state in
            switch action {
            case .child(.tick): state.child.n += 1
            }
        })
        let projected = base.projection(full)
        projected.dispatch(.tick)
        #expect(base.state.child.n == 1)
        #expect(projected.state.n == 1)
    }
}
