import CoreFP
import DataStructure
@testable import SwiftRex
import Testing

// MARK: - Shared fixtures

private struct GA: Sendable { var local: Int?; var other: String? }
private struct GS: Sendable { var local: Int = 0; var other: Int = 99 }
private struct GE: Sendable { var sub: Int = 0; var other: String = "" }

private let anySource = ActionSource(file: #file, function: #function, line: #line)

// MARK: - Test helpers

@MainActor
private func dispatch<A: Sendable, S: Sendable, E: Sendable>(
    _ middleware: Middleware<A, S, E>,
    action: A,
    state: S,
    env: E
) -> Effect<A> {
    let preCtx = PreReducerContext<S>(source: anySource, getter: { state })
    let postCtx = PostReducerContext<S, E>(environment: env, getter: { state })
    return middleware.handle(action, preCtx).runReader(postCtx)
}

@MainActor
private func actions<A: Sendable, S: Sendable, E: Sendable>(
    _ middleware: Middleware<A, S, E>,
    action: A,
    state: S,
    env: E
) -> [A] {
    let received = LockProtected([A]())
    subscribeAll(dispatch(middleware, action: action, state: state, env: env)) { d in
        received.mutate { $0.append(d.action) }
    }
    return received.value
}

// MARK: - Named constructors

@Suite("Middleware constructors")
@MainActor
struct MiddlewareConstructorTests {
    @Test func handleClosureReturnsExpectedEffect() {
        let sut = Middleware<Int, Int, Void>.handle { action, _ in
            Reader { _ in .just(action * 2) }
        }
        #expect(actions(sut, action: 5, state: 0, env: ()) == [10])
    }

    @Test func handleWithProduceShorthand() {
        let sut = Middleware<Int, Int, Void>.handle { action, _ in .produce { _ in .just(action + 1) } }
        #expect(actions(sut, action: 3, state: 0, env: ()) == [4])
    }
}

// MARK: - Monoid

@Suite("Middleware Monoid")
@MainActor
struct MiddlewareMonoidTests {
    @Test func identityProducesNoEffect() {
        #expect(actions(Middleware<Int, Int, Void>.identity, action: 42, state: 0, env: ()).isEmpty)
    }

    @Test func combineMergesEffectsFromBoth() {
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action) } }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action * 10) } }
        #expect(actions(Middleware.combine(lhs, rhs), action: 2, state: 0, env: ()).sorted() == [2, 20])
    }

    @Test func combineBothSeeTheSameAction() {
        let seen = LockProtected([Int]())
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in
            Reader { _ in seen.mutate { $0.append(action) }; return .empty }
        }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in
            Reader { _ in seen.mutate { $0.append(action) }; return .empty }
        }
        _ = actions(Middleware.combine(lhs, rhs), action: 7, state: 0, env: ())
        #expect(seen.value == [7, 7])
    }

    @Test func leftIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action) } }
        #expect(actions(Middleware.combine(.identity, m), action: 5, state: 0, env: ()) == [5])
    }

    @Test func rightIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action) } }
        #expect(actions(Middleware.combine(m, .identity), action: 5, state: 0, env: ()) == [5])
    }
}

// MARK: - liftAction

@Suite("Middleware liftAction")
@MainActor
struct MiddlewareLiftActionTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let doubler = Middleware<Int, Int, Void>.handle { action, _ in
        Reader { _ in .just(action * 2) }
    }

    @Test func matchingActionReachesMiddleware() {
        let sut = doubler.liftAction(prism)
        let received = LockProtected([GA]())
        subscribeAll(
            sut.handle(GA(local: 4, other: nil), PreReducerContext(source: anySource, getter: { 0 }))
                .runReader(PostReducerContext(environment: (), getter: { 0 }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.first?.local == 8)
    }

    @Test func nonMatchingActionProducesEmptyEffect() {
        let sut = doubler.liftAction(prism)
        let effect = sut.handle(GA(local: nil, other: "x"), PreReducerContext(source: anySource, getter: { 0 }))
            .runReader(PostReducerContext(environment: (), getter: { 0 }))
        #expect(effect.components.isEmpty)
    }

    @Test func outputActionIsWrappedViaReview() {
        let sut = doubler.liftAction(prism)
        let received = LockProtected([GA]())
        subscribeAll(
            sut.handle(GA(local: 3, other: nil), PreReducerContext(source: anySource, getter: { 0 }))
                .runReader(PostReducerContext(environment: (), getter: { 0 }))
        ) { d in received.mutate { $0.append(d.action) } }
        // review(3*2) → GA(local: 6, other: nil)
        #expect(received.value.first?.local == 6)
        #expect(received.value.first?.other == nil)
    }
}

// MARK: - liftState

@Suite("Middleware liftState")
@MainActor
struct MiddlewareLiftStateTests {
    private let statePasser = Middleware<Int, Int, Void>.handle { _, context in
        let pre = context.stateBefore
        return Reader { _ in
            guard let pre else { return .empty }
            return .just(pre)
        }
    }

    @Test func liftStateClosureProjectsSubState() {
        let sut = statePasser.liftState { (gs: GS) in gs.local }
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext(source: anySource, getter: { GS(local: 55, other: 0) }))
                .runReader(PostReducerContext(environment: (), getter: { GS(local: 55, other: 0) }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [55])
    }

    @Test func liftStateLensProjectsSubState() {
        let lens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = statePasser.liftState(lens)
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext(source: anySource, getter: { GS(local: 77, other: 0) }))
                .runReader(PostReducerContext(environment: (), getter: { GS(local: 77, other: 0) }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [77])
    }

    @Test func liftStatePrismReturnsNilWhenCaseInactive() {
        let prism = Prism<Int?, Int>(preview: { $0 }, review: { Optional($0) })
        let sut = statePasser.liftState(prism)
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext<Int?>(source: anySource, getter: { nil }))
                .runReader(PostReducerContext<Int?, Void>(environment: (), getter: { nil }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.isEmpty)
    }
}

// MARK: - liftEnvironment

@Suite("Middleware liftEnvironment")
@MainActor
struct MiddlewareLiftEnvironmentTests {
    @Test func liftEnvironmentProjectsEnv() {
        let sut = Middleware<Int, Int, Int>.handle { _, _ in
            Reader { ctx in .just(ctx.environment) }
        }.liftEnvironment { (ge: GE) in ge.sub }
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext(source: anySource, getter: { 0 }))
                .runReader(PostReducerContext(environment: GE(sub: 33, other: ""), getter: { 0 }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [33])
    }
}

// MARK: - liftState AffineTraversal

@Suite("Middleware liftState AffineTraversal")
@MainActor
struct MiddlewareLiftStateATTests {
    private let statePasser = Middleware<Int, Int, Void>.handle { _, context in
        let pre = context.stateBefore
        return Reader { _ in
            guard let pre else { return .empty }
            return .just(pre)
        }
    }

    private let optionalIntAT = AffineTraversal<Int?, Int>(
        preview: { $0 },
        set: { _, v in Optional(v) }
    )

    @Test func liftStateATProjectsSubStateWhenFocusPresent() {
        let sut = statePasser.liftState(optionalIntAT)
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext<Int?>(source: anySource, getter: { .some(55) }))
                .runReader(PostReducerContext<Int?, Void>(environment: (), getter: { .some(55) }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [55])
    }

    @Test func liftStateATReturnsNilWhenFocusAbsent() {
        let sut = statePasser.liftState(optionalIntAT)
        let received = LockProtected([Int]())
        subscribeAll(
            sut.handle(0, PreReducerContext<Int?>(source: anySource, getter: { nil }))
                .runReader(PostReducerContext<Int?, Void>(environment: (), getter: { nil }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.isEmpty)
    }
}

// MARK: - Combined lift

@Suite("Middleware combined lift")
@MainActor
struct MiddlewareCombinedLiftTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let base = Middleware<Int, Int, Int>.handle { action, _ in
        Reader { ctx in .just(action + ctx.environment) }
    }

    @Test func liftAllThreeAxesClosure() {
        let sut = base.lift(
            action: prism,
            state: { (gs: GS) in gs.local },
            environment: { (ge: GE) in ge.sub }
        )
        let received = LockProtected([GA]())
        subscribeAll(
            sut.handle(GA(local: 2, other: nil), PreReducerContext(source: anySource, getter: { GS() }))
                .runReader(PostReducerContext(environment: GE(sub: 3, other: ""), getter: { GS() }))
        ) { d in received.mutate { $0.append(d.action) } }
        // action=2 + env=3 = 5, wrapped via review → GA(local: 5)
        #expect(received.value.first?.local == 5)
    }

    @Test func liftAllThreeAxesLens() {
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = base.lift(action: prism, state: stateLens, environment: { (ge: GE) in ge.sub })
        let received = LockProtected([GA]())
        subscribeAll(
            sut.handle(GA(local: 1, other: nil), PreReducerContext(source: anySource, getter: { GS() }))
                .runReader(PostReducerContext(environment: GE(sub: 4, other: ""), getter: { GS() }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.first?.local == 5)
    }

    @Test func liftSkipsWhenActionNotMatched() {
        let sut = base.lift(
            action: prism,
            state: { (gs: GS) in gs.local },
            environment: { (ge: GE) in ge.sub }
        )
        let effect = sut.handle(GA(local: nil, other: "x"), PreReducerContext(source: anySource, getter: { GS() }))
            .runReader(PostReducerContext(environment: GE(sub: 0, other: ""), getter: { GS() }))
        #expect(effect.components.isEmpty)
    }
}

// MARK: - Context timing: pre vs post state

@Suite("Middleware context timing")
@MainActor
struct MiddlewareContextTimingTests {
    @Test func handleCapturesPreStateReaderSeesPostState() {
        let stateBox = LockProtected(0)
        let sut = Middleware<Int, Int, Void>.handle { _, context in
            let pre = context.stateBefore ?? 0   // phase 1 — @MainActor, reads pre-mutation state
            return Reader { ctx in
                let post = MainActor.assumeIsolated { ctx.stateAfter } ?? 0
                return .just(pre + post)
            }
        }
        let preCtx = PreReducerContext<Int>(source: anySource, getter: { stateBox.value })
        let reader = sut.handle(0, preCtx)
        stateBox.set(10)   // mutate after handle captures pre-state
        let received = LockProtected([Int]())
        let postCtx = PostReducerContext<Int, Void>(environment: (), getter: { stateBox.value })
        subscribeAll(reader.runReader(postCtx)) { d in received.mutate { $0.append(d.action) } }
        // pre=0, post=10 → 0+10=10
        #expect(received.value == [10])
    }
}
