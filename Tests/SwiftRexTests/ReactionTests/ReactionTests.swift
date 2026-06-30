import CoreFP
import DataStructure
import Hourglass
@testable import SwiftRex
import Testing

// MARK: - The supervise axis on Behavior / Middleware (the state-driven Sub side)

@Suite("Behavior/Middleware supervise")
@MainActor
struct SuperviseTests {
    private struct S: Sendable { var connected = false }
    private enum A: Sendable {}

    /// The channels a behavior supervises for `state` (Void environment) — `nil` supervisor ⇒ `[]`.
    private func channels(_ behavior: Behavior<A, S, Void>, _ state: S) -> [Channel<A>] {
        behavior.supervisor?(state).runReader(()) ?? []
    }

    /// Generic resolver for the lifted behaviors (varied state/environment types).
    private func resolve<Act: Sendable, St: Sendable, Env: Sendable>(
        _ behavior: Behavior<Act, St, Env>, _ state: St, _ env: Env
    ) -> [Channel<Act>] {
        behavior.supervisor?(state).runReader(env) ?? []
    }

    nonisolated private func channel(_ id: String) -> Channel<A> {
        Channel(id: id) { _ in .cancelOnly {} }
    }

    @Test func behaviorSuperviseDerivesChannelsFromState() {
        let behavior = Behavior<A, S, Void>.supervise { state in
            Supervision { _ in state.connected ? [channel("socket")] : [] }
        }
        #expect(channels(behavior, S(connected: true)).count == 1)
        #expect(channels(behavior, S(connected: false)).isEmpty)
    }

    @Test func combineUnionsSupervise() {
        let a = Behavior<A, S, Void>.supervise { _ in Supervision { _ in [channel("a")] } }
        let b = Behavior<A, S, Void>.supervise { _ in Supervision { _ in [channel("b")] } }
        #expect(channels(.combine(a, b), S()).count == 2)
    }

    @Test func identityBehaviorSupervisesNothing() {
        #expect(channels(.identity, S()).isEmpty)
    }

    @Test func combineWithIdentityIsTheUnit() {
        let r = Behavior<A, S, Void>.supervise { _ in Supervision { _ in [channel("x")] } }
        #expect(channels(.combine(.identity, r), S()).count == 1)
        #expect(channels(.combine(r, .identity), S()).count == 1)
    }

    @Test func middlewareSuperviseCarriesThroughAsBehavior() {
        let middleware = Middleware<A, S, Void>.supervise { _ in Supervision { _ in [channel("m")] } }
        #expect(channels(middleware.asBehavior, S()).count == 1)
    }

    @Test func reducerMiddlewareBehaviorCarriesMiddlewareSupervise() {
        let middleware = Middleware<A, S, Void>.supervise { _ in Supervision { _ in [channel("m")] } }
        let behavior = Behavior(reducer: .identity, middleware: middleware)
        #expect(channels(behavior, S()).count == 1)
    }

    // MARK: - The `supervises` bypass flag (a non-supervising feature does no phase-5 work)

    @Test func supervisesFlagIsStructuralAndPropagates() {
        struct Global: Sendable { var sub = S() }
        typealias B = Behavior<A, S, Void>
        // Leaves
        #expect(B.identity.supervises == false)
        #expect(B.reduce { _, _ in }.supervises == false)
        #expect(B.produce { _, _ in Reader { _ in .empty } }.supervises == false)
        #expect(B.supervise { _ in Supervision { _ in [] } }.supervises == true)
        // combine unions the flag
        #expect(B.combine(.reduce { _, _ in }, .produce { _, _ in Reader { _ in .empty } }).supervises == false)
        #expect(B.combine(.reduce { _, _ in }, .supervise { _ in Supervision { _ in [] } }).supervises == true)
        // lifts preserve it
        #expect(B.reduce { _, _ in }.liftState(\Global.sub).supervises == false)
        #expect(B.supervise { _ in Supervision { _ in [] } }.liftState(\Global.sub).supervises == true)
        // Middleware mirrors it, including through asBehavior
        #expect(Middleware<A, S, Void>.produce { _, _ in Reader { _ in .empty } }.supervises == false)
        #expect(Middleware<A, S, Void>.supervise { _ in Supervision { _ in [] } }.supervises == true)
        #expect(Middleware<A, S, Void>.supervise { _ in Supervision { _ in [] } }.asBehavior.supervises == true)
        // Providing a supervisor to the public Middleware init means it supervises (no silent drop)
        #expect(Middleware<A, S, Void>(handle: { _, _ in Reader { _ in .empty } }, supervisor: { _ in Supervision { _ in [] } }).supervises == true)
    }

    @Test func superviseReadsTheEnvironment() {
        struct Env: Sendable { let ids: [String] }
        let behavior = Behavior<A, S, Env>.supervise { _ in
            Supervision { env in env.ids.map { id in Channel(id: id) { _ in .cancelOnly {} } } }
        }
        #expect(resolve(behavior, S(), Env(ids: ["a", "b", "c"])).count == 3)
    }

    // MARK: - Fluent chaining (instance == self <> static)

    @Test func fluentBehaviorChainFoldsAllThreeConcerns() {
        // .reduce { … }.produce { … }.supervise { … } — three concerns folded by combine.
        let chained = Behavior<A, S, Void>
            .reduce { _, state in state.connected = true }
            .produce { _, _ in Reader { _ in .empty } }
            .supervise { _ in Supervision { _ in [channel("a")] } }
        let reactionCount = chained.consequences.filter { if case .reaction = $0 { true } else { false } }.count
        #expect(reactionCount == 2)                  // reduce + produce on the action axis
        #expect(chained.consequences.count == 3)     // + the one supervision
        #expect(channels(chained, S()).count == 1)   // supervise carried through the chain
    }

    @Test func fluentMiddlewareSuperviseAndReactChain() {
        let middleware = Middleware<A, S, Void>
            .supervise { _ in Supervision { _ in [channel("m")] } }
            .produce { _, _ in Reader { _ in .empty } }
        #expect(channels(middleware.asBehavior, S()).count == 1)
    }

    // MARK: - supervise threads through the lifts

    @Test func supervisorThreadsThroughStateLift() {
        struct Global: Sendable { var sub = S() }
        let feature = Behavior<A, S, Void>.supervise { state in
            Supervision { _ in state.connected ? [channel("socket")] : [] }
        }
        let lifted = feature.liftState(\Global.sub)
        #expect(resolve(lifted, Global(sub: S(connected: true)), ()).count == 1)
        #expect(resolve(lifted, Global(sub: S(connected: false)), ()).isEmpty)
    }

    private enum Nav: Sendable { case loggedOut; case loggedIn(S) }

    @Test func supervisorIsCancelledWhenPrismStateFocusIsAbsent() {
        // The state-driven-nav payoff: sub-state gone → no channels → reconciler cancels them.
        let prism = Prism<Nav, S>(
            preview: { if case .loggedIn(let s) = $0 { s } else { nil } },
            review: Nav.loggedIn
        )
        let feature = Behavior<A, S, Void>.supervise { _ in Supervision { _ in [channel("socket")] } }
        let lifted = feature.liftState(prism)
        #expect(resolve(lifted, .loggedIn(S()), ()).count == 1)
        #expect(resolve(lifted, .loggedOut, ()).isEmpty)
    }

    @Test func supervisorThreadsThroughCollectionLiftWithPerElementStamping() {
        struct Item: Sendable, Identifiable { let id: Int; var connected: Bool }
        struct Global: Sendable { var items: [Item] }
        let feature = Behavior<A, Item, Void>.supervise { item in
            Supervision { _ in item.connected ? [Channel(id: "socket") { _ in .cancelOnly {} }] : [] }
        }
        let lifted = feature.liftCollection(
            action: Prism<ElementAction<Int, A>, ElementAction<Int, A>>(preview: { $0 }, review: { $0 }),
            stateCollection: \Global.items
        )
        // Two connected elements → two channels, with element-scoped (distinct) ids.
        let both = resolve(lifted, Global(items: [Item(id: 1, connected: true), Item(id: 2, connected: true)]), ())
        #expect(both.count == 2)
        #expect(Set(both.map(\.id)).count == 2)
        // Dropping an element's implying state cancels only that element's channel.
        let one = resolve(lifted, Global(items: [Item(id: 1, connected: true), Item(id: 2, connected: false)]), ())
        #expect(one.count == 1)
    }

    @Test func supervisorThreadsThroughLiftEachWithPerElementStamping() {
        struct Item: Sendable, Identifiable { let id: Int; var connected: Bool }
        struct Global: Sendable { var items: [Item] }
        let feature = Behavior<A, Item, Void>.supervise { item in
            Supervision { _ in item.connected ? [Channel(id: "socket") { _ in .cancelOnly {} }] : [] }
        }
        let lifted = feature.liftEach(action: { _ in nil }, embed: { a, _ in a }, stateCollection: \Global.items)
        // Fan-out supervise: every connected element keeps its own element-scoped (distinct) channel.
        let both = resolve(lifted, Global(items: [Item(id: 1, connected: true), Item(id: 2, connected: true)]), ())
        #expect(both.count == 2)
        #expect(Set(both.map(\.id)).count == 2)
        let one = resolve(lifted, Global(items: [Item(id: 1, connected: true), Item(id: 2, connected: false)]), ())
        #expect(one.count == 1)
    }

    @Test func supervisorThreadsThroughEnvironmentLift() {
        struct InnerEnv: Sendable { let ids: [String] }
        struct GlobalEnv: Sendable { let inner: InnerEnv }
        let feature = Behavior<A, S, InnerEnv>.supervise { _ in
            Supervision { env in env.ids.map { id in Channel(id: id) { _ in .cancelOnly {} } } }
        }
        let lifted = feature.liftEnvironment { (g: GlobalEnv) in g.inner }
        #expect(resolve(lifted, S(), GlobalEnv(inner: InnerEnv(ids: ["a", "b"]))).count == 2)
    }
}
