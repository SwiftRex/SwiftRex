import CoreFP
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - The supervise axis on Behavior / Middleware (the state-driven Sub side)

@Suite("Behavior/Middleware supervise")
@MainActor
struct SuperviseTests {
    private struct S: Sendable { var connected = false }
    private enum A: Sendable {}

    /// The channels a behavior supervises for `state` (Void environment).
    private func channels(_ behavior: Behavior<A, S, Void>, _ state: S) -> [Channel<A>] {
        behavior.supervise(state).runReader(())
    }

    nonisolated private func channel(_ id: String) -> Channel<A> {
        Channel(id: id) { _ in .cancelOnly {} }
    }

    @Test func behaviorSuperviseDerivesChannelsFromState() {
        let behavior = Behavior<A, S, Void>.supervise { state in
            Keep { _ in state.connected ? [channel("socket")] : [] }
        }
        #expect(channels(behavior, S(connected: true)).count == 1)
        #expect(channels(behavior, S(connected: false)).isEmpty)
    }

    @Test func combineUnionsSupervise() {
        let a = Behavior<A, S, Void>.supervise { _ in Keep { _ in [channel("a")] } }
        let b = Behavior<A, S, Void>.supervise { _ in Keep { _ in [channel("b")] } }
        #expect(channels(.combine(a, b), S()).count == 2)
    }

    @Test func identityBehaviorSupervisesNothing() {
        #expect(channels(.identity, S()).isEmpty)
    }

    @Test func combineWithIdentityIsTheUnit() {
        let r = Behavior<A, S, Void>.supervise { _ in Keep { _ in [channel("x")] } }
        #expect(channels(.combine(.identity, r), S()).count == 1)
        #expect(channels(.combine(r, .identity), S()).count == 1)
    }

    @Test func middlewareSuperviseCarriesThroughAsBehavior() {
        let middleware = Middleware<A, S, Void>.supervise { _ in Keep { _ in [channel("m")] } }
        #expect(channels(middleware.asBehavior, S()).count == 1)
    }

    @Test func reducerMiddlewareBehaviorCarriesMiddlewareSupervise() {
        let middleware = Middleware<A, S, Void>.supervise { _ in Keep { _ in [channel("m")] } }
        let behavior = Behavior(reducer: .identity, middleware: middleware)
        #expect(channels(behavior, S()).count == 1)
    }

    @Test func superviseReadsTheEnvironment() {
        struct Env: Sendable { let ids: [String] }
        let behavior = Behavior<A, S, Env>.supervise { _ in
            Keep { env in env.ids.map { id in Channel(id: id) { _ in .cancelOnly {} } } }
        }
        #expect(behavior.supervise(S()).runReader(Env(ids: ["a", "b", "c"])).count == 3)
    }
}
