#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
@testable import SwiftRex
@testable import SwiftRexArchitecture
import SwiftUI
import Testing

// A child feature (a real @Feature so it conforms to `Feature`: behavior + view). Scope derives both
// its lifted behavior and its view from it.
@Feature(type: .internalOnly, strategy: .observationSimple)
enum SCCounter {
    struct State: Sendable, Equatable { var count = 0 }
    enum Action: Sendable, Equatable { case inc, pull, add(Int) }
    struct Environment: Sendable { var step: Int }

    static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, _ in
            switch action {
            case .inc:        .reduce { $0.count += 1 }
            case .pull:       .produce { ctx in Effect.just(.add(ctx.environment.step)) }  // reads env
            case .add(let n): .reduce { $0.count += n }
            }
        }
    }
    typealias Content = SCCounterView
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@BoundTo(SCCounter.self, strategy: .observationSimple)
struct SCCounterView: View { var body: some View { Text("\(viewStore.state.count)") } }

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension SCCounter: Feature {}   // one-line conformance

// @Prisms/@Lenses require >= fileprivate.
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
    // The Scope literal is a compile-time proof of wiring — it wouldn't compile if the action case,
    // state slot, or env-narrowing didn't line up with SCCounter's own types.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    private func counterScope() -> Scope<SCAction, SCState, SCWorld, SCCounter> {
        Scope<SCAction, SCState, SCWorld, SCCounter>(SCCounter.self, action: \.counter, state: \.counter, environment: { _ in .init(step: 0) })
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func behaviorLiftsActionAndState() {
        let store = Store(initial: SCState(), behavior: counterScope().behavior, environment: SCWorld())
        store.dispatch(.counter(.inc))
        #expect(store.state.counter.count == 1)   // action prism + state key path both applied
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func envIsNarrowedFromWorld() async {
        let scope = Scope<SCAction, SCState, SCWorld, SCCounter>(
            SCCounter.self,
            action: \.counter,
            state: \SCState.counter,
            environment: { (w: SCWorld) in SCCounter.Environment(step: w.step) }
        )
        let store = Store(initial: SCState(), behavior: scope.behavior, environment: SCWorld(step: 7))
        store.dispatch(.counter(.pull))            // effect reads env.step=7 → .add(7)
        await Task.yield()
        #expect(store.state.counter.count == 7)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func envAsKeyPathConvenience() async {
        let scope = Scope<SCAction, SCState, SCWorld, SCCounter>(
            SCCounter.self,
            action: \.counter,
            state: \SCState.counter,
            environment: \SCWorld.counterEnv
        )
        let store = Store(initial: SCState(), behavior: scope.behavior, environment: SCWorld(step: 3))
        store.dispatch(.counter(.pull))
        await Task.yield()
        #expect(store.state.counter.count == 3)   // env-narrow via key path reached the effect
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func scopeBuildsTheChildView() {
        // Scope drives BOTH: .behavior (above) and .view here — env supplied from the world.
        let store = Store(initial: SCState(), behavior: counterScope().behavior, environment: SCWorld())
        _ = counterScope().view(from: store, world: SCWorld())
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func scopesRegistryFoldsBehaviors() {
        let app = Scopes(counterScope().behavior).behavior
        let store = Store(initial: SCState(), behavior: app, environment: SCWorld())
        store.dispatch(.counter(.inc))
        #expect(store.state.counter.count == 1)
    }
    // (Optional/modal children register their behavior via `liftOptional` — covered in the behavior
    // tests; `Scope` here is present-state and drives both behavior and view.)
}
#endif
