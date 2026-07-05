#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
@testable import SwiftRexArchitecture
import Testing

// A child feature reduced to the essentials Scope needs: a behavior + (Action, State, Environment).
// No @Feature required — Scope takes the behavior + optics as values.
private enum SCCounter {
    struct State: Sendable, Equatable { var count = 0 }
    enum Action: Sendable, Equatable { case inc, pull, add(Int) }
    struct Environment: Sendable { var step: Int }

    static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .inc:        .reduce { $0.count += 1 }
            case .pull:       .produce { ctx in Effect.just(.add(ctx.environment.step)) } // reads env
            case .add(let n): .reduce { $0.count += n }
            }
        }
    }
}

// @Prisms/@Lenses require >= fileprivate (they reject `private`).
// swiftlint:disable private_over_fileprivate
@Prisms
fileprivate enum SCAction: Sendable, Equatable {
    case counter(SCCounter.Action)
    case sheet(SCCounter.Action)
}

@Lenses
fileprivate struct SCState: Sendable, Equatable {
    var counter = SCCounter.State()
    var sheet: SCCounter.State?
}
// swiftlint:enable private_over_fileprivate

private struct SCWorld: Sendable {
    var step: Int = 10
    var counterEnv: SCCounter.Environment { .init(step: step) }
}

@Suite("Scope")
@MainActor
struct ScopeTests {
    // The Scope literal itself is a compile-time proof of wiring: it would not compile if the
    // action case, state slot, or env-narrowing didn't line up with SCCounter's own types.
    private func counterScope() -> Scope<SCAction, SCState, SCWorld> {
        Scope(behavior: SCCounter.behavior(), action: \.counter, state: \.counter, environment: { _ in .init(step: 0) })
    }

    @Test func presentScopeLiftsActionAndState() {
        let store = Store(initial: SCState(), behavior: counterScope().lifted, environment: SCWorld())
        store.dispatch(.counter(.inc))
        #expect(store.state.counter.count == 1) // action prism + state key path both applied
    }

    @Test func envIsNarrowedFromWorld() async {
        let scope = Scope<SCAction, SCState, SCWorld>(
            behavior: SCCounter.behavior(),
            action: \.counter,
            state: \.counter,
            environment: { SCCounter.Environment(step: $0.step) } // narrow SCWorld.step
        )
        let store = Store(initial: SCState(), behavior: scope.lifted, environment: SCWorld(step: 7))
        store.dispatch(.counter(.pull)) // effect reads env.step=7 → .add(7)
        await Task.yield()
        #expect(store.state.counter.count == 7)
    }

    @Test func envAsKeyPathConvenience() async {
        let scope = Scope<SCAction, SCState, SCWorld>(
            behavior: SCCounter.behavior(),
            action: \.counter,
            state: \.counter,
            environment: \.counterEnv // KeyPath<SCWorld, SCCounter.Environment>
        )
        let store = Store(initial: SCState(), behavior: scope.lifted, environment: SCWorld(step: 3))
        store.dispatch(.counter(.pull))
        await Task.yield()
        #expect(store.state.counter.count == 3) // env-narrow via key path reached the effect
    }

    @Test func optionalScopeRunsWhenSome() {
        let scope = Scope<SCAction, SCState, SCWorld>(
            behavior: SCCounter.behavior(),
            action: \.sheet,
            state: \.sheet, // WritableKeyPath<SCState, SCCounter.State?>
            environment: { _ in .init(step: 0) }
        )
        var initial = SCState(); initial.sheet = SCCounter.State(count: 5)
        let store = Store(initial: initial, behavior: scope.lifted, environment: SCWorld())
        store.dispatch(.sheet(.inc))
        #expect(store.state.sheet?.count == 6)
    }

    @Test func optionalScopeSkipsWhenNil() {
        let scope = Scope<SCAction, SCState, SCWorld>(
            behavior: SCCounter.behavior(),
            action: \.sheet,
            state: \.sheet,
            environment: { _ in .init(step: 0) }
        )
        let store = Store(initial: SCState(), behavior: scope.lifted, environment: SCWorld()) // sheet nil
        store.dispatch(.sheet(.inc))
        #expect(store.state.sheet == nil) // child behavior never runs while slice is nil
    }

    @Test func scopesFoldIntoOneAppBehavior() {
        let app = Behavior.combine([counterScope().lifted])
        let store = Store(initial: SCState(), behavior: app, environment: SCWorld())
        store.dispatch(.counter(.inc))
        #expect(store.state.counter.count == 1)
    }
}
#endif
