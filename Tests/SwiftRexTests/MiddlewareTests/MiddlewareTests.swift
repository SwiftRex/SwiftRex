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
    let dispatched = DispatchedAction(action, dispatcher: anySource)
    let access = StateAccess<S> { state }
    let mReader = middleware.handle(dispatched, access)
    let ctx = MiddlewareEnvironment(environment: env, stateAccess: { access.snapshotState() })
    return mReader.run(ctx)
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

/// Convenience: run a `MiddlewareReader` with a fixed state snapshot.
@MainActor
private func runMReader<A: Sendable, S: Sendable, E: Sendable>(
    _ mReader: MiddlewareReader<A, E, S>,
    state: S,
    env: E
) -> Effect<A> {
    let access = StateAccess<S> { state }
    let ctx = MiddlewareEnvironment(environment: env, stateAccess: { access.snapshotState() })
    return mReader.run(ctx)
}

/// Convenience: run a `MiddlewareReader` with a `StateAccess` and explicit env.
@MainActor
private func runMReader<A: Sendable, S: Sendable, E: Sendable>(
    _ mReader: MiddlewareReader<A, E, S>,
    access: StateAccess<S>,
    env: E
) -> Effect<A> {
    let ctx = MiddlewareEnvironment(environment: env, stateAccess: { access.snapshotState() })
    return mReader.run(ctx)
}

// MARK: - Named constructors

@Suite("Middleware constructors")
@MainActor
struct MiddlewareConstructorTests {
    @Test func handleClosureReturnsExpectedEffect() {
        let sut = Middleware<Int, Int, Void>.handle { action, _ in
            MiddlewareReader { _ in .just(action.action * 2) }
        }
        #expect(actions(sut, action: 5, state: 0, env: ()) == [10])
    }

    @Test func handleVoidEnvironmentConvenience() {
        let sut = Middleware<Int, Int, Void>.handle { action, _ in .just(action.action + 1) }
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
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in MiddlewareReader { _ in .just(action.action) } }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in MiddlewareReader { _ in .just(action.action * 10) } }
        #expect(actions(Middleware.combine(lhs, rhs), action: 2, state: 0, env: ()).sorted() == [2, 20])
    }

    @Test func combineBothSeeTheSameAction() {
        let seen = LockProtected([Int]())
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in
            MiddlewareReader { _ in seen.mutate { $0.append(action.action) }; return .empty }
        }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in
            MiddlewareReader { _ in seen.mutate { $0.append(action.action) }; return .empty }
        }
        _ = actions(Middleware.combine(lhs, rhs), action: 7, state: 0, env: ())
        #expect(seen.value == [7, 7])
    }

    @Test func leftIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in MiddlewareReader { _ in .just(action.action) } }
        #expect(actions(Middleware.combine(.identity, m), action: 5, state: 0, env: ()) == [5])
    }

    @Test func rightIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in MiddlewareReader { _ in .just(action.action) } }
        #expect(actions(Middleware.combine(m, .identity), action: 5, state: 0, env: ()) == [5])
    }
}

// MARK: - liftAction

@Suite("Middleware liftAction")
@MainActor
struct MiddlewareLiftActionTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let doubler = Middleware<Int, Int, Void>.handle { action, _ in
        MiddlewareReader { _ in .just(action.action * 2) }
    }

    @Test func matchingActionReachesMiddleware() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: 4, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { 0 }), state: 0, env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.first?.local == 8)
    }

    @Test func nonMatchingActionProducesEmptyEffect() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: nil, other: "x"), dispatcher: anySource)
        let effect = runMReader(sut.handle(dispatched, StateAccess { 0 }), state: 0, env: ())
        #expect(effect.components.isEmpty)
    }

    @Test func outputActionIsWrappedViaReview() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: 3, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { 0 }), state: 0, env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        // review(3*2) → GA(local: 6, other: nil)
        #expect(received.value.first?.local == 6)
        #expect(received.value.first?.other == nil)
    }
}

// MARK: - liftState

@Suite("Middleware liftState")
@MainActor
struct MiddlewareLiftStateTests {
    private let statePasser = Middleware<Int, Int, Void>.handle { _, stateAccess in
        let pre = stateAccess.snapshotState()
        return MiddlewareReader { _ in
            guard let pre else { return .empty }
            return .just(pre)
        }
    }

    @Test func liftStateClosureProjectsSubState() {
        let sut = statePasser.liftState { (gs: GS) in gs.local }
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { GS(local: 55, other: 0) }),
                                state: GS(local: 55, other: 0), env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [55])
    }

    @Test func liftStateLensProjectsSubState() {
        let lens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = statePasser.liftState(lens)
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { GS(local: 77, other: 0) }),
                                state: GS(local: 77, other: 0), env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [77])
    }

    @Test func liftStatePrismReturnsNilWhenCaseInactive() {
        let prism = Prism<Int?, Int>(preview: { $0 }, review: { Optional($0) })
        let sut = statePasser.liftState(prism)
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess<Int?> { nil }),
                                state: Optional<Int>.none, env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.isEmpty)
    }
}

// MARK: - liftEnvironment

@Suite("Middleware liftEnvironment")
@MainActor
struct MiddlewareLiftEnvironmentTests {
    @Test func liftEnvironmentProjectsEnv() {
        let sut = Middleware<Int, Int, Int>.handle { _, _ in
            MiddlewareReader { ctx in .just(ctx.environment) }
        }.liftEnvironment { (ge: GE) in ge.sub }
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { 0 }),
                                state: 0, env: GE(sub: 33, other: ""))) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [33])
    }
}

// MARK: - liftState AffineTraversal

@Suite("Middleware liftState AffineTraversal")
@MainActor
struct MiddlewareLiftStateATTests {
    private let statePasser = Middleware<Int, Int, Void>.handle { _, stateAccess in
        let pre = stateAccess.snapshotState()
        return MiddlewareReader { _ in
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
        subscribeAll(runMReader(sut.handle(DispatchedAction(0, dispatcher: anySource),
                                           StateAccess<Int?> { .some(55) }),
                                state: Optional<Int>.some(55), env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [55])
    }

    @Test func liftStateATReturnsNilWhenFocusAbsent() {
        let sut = statePasser.liftState(optionalIntAT)
        let received = LockProtected([Int]())
        subscribeAll(runMReader(sut.handle(DispatchedAction(0, dispatcher: anySource),
                                           StateAccess<Int?> { nil }),
                                state: Optional<Int>.none, env: ())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.isEmpty)
    }
}

// MARK: - Combined lift

@Suite("Middleware combined lift")
@MainActor
struct MiddlewareCombinedLiftTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let base = Middleware<Int, Int, Int>.handle { action, _ in
        MiddlewareReader { ctx in .just(action.action + ctx.environment) }
    }

    @Test func liftAllThreeAxesClosure() {
        let sut = base.lift(
            action: prism,
            state: { (gs: GS) in gs.local },
            environment: { (ge: GE) in ge.sub }
        )
        let dispatched = DispatchedAction(GA(local: 2, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { GS() }),
                                state: GS(), env: GE(sub: 3, other: ""))) { d in
            received.mutate { $0.append(d.action) }
        }
        // action=2 + env=3 = 5, wrapped via review → GA(local: 5)
        #expect(received.value.first?.local == 5)
    }

    @Test func liftAllThreeAxesLens() {
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = base.lift(action: prism, state: stateLens, environment: { (ge: GE) in ge.sub })
        let dispatched = DispatchedAction(GA(local: 1, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(runMReader(sut.handle(dispatched, StateAccess { GS() }),
                                state: GS(), env: GE(sub: 4, other: ""))) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.first?.local == 5)
    }

    @Test func liftSkipsWhenActionNotMatched() {
        let sut = base.lift(
            action: prism,
            state: { (gs: GS) in gs.local },
            environment: { (ge: GE) in ge.sub }
        )
        let dispatched = DispatchedAction(GA(local: nil, other: "x"), dispatcher: anySource)
        let effect = runMReader(sut.handle(dispatched, StateAccess { GS() }),
                                state: GS(), env: GE(sub: 0, other: ""))
        #expect(effect.components.isEmpty)
    }
}

// MARK: - StateAccess timing: pre vs post mutation

@Suite("Middleware StateAccess timing")
@MainActor
struct MiddlewareStateAccessTimingTests {
    @Test func handleCapturesPreStateReaderSeesPostState() {
        let stateBox = LockProtected(0)
        let access = StateAccess<Int> { stateBox.value }
        let sut = Middleware<Int, Int, Void>.handle { _, stateAccess in
            let pre = stateAccess.snapshotState() ?? 0
            // Phase 3: MiddlewareReader.run is @MainActor — ctx.stateAccess() is directly callable.
            return MiddlewareReader { ctx in
                let post = ctx.stateAccess() ?? 0   // No assumeIsolated needed!
                return .just(pre + post)
            }
        }
        let mReader = sut.handle(DispatchedAction(0, dispatcher: anySource), access)
        stateBox.set(10)   // mutate after handle captures pre-state
        let received = LockProtected([Int]())
        let ctx = MiddlewareEnvironment(environment: (), stateAccess: { access.snapshotState() })
        subscribeAll(mReader.run(ctx)) { d in received.mutate { $0.append(d.action) } }
        // pre=0, post=10 → 0+10=10
        #expect(received.value == [10])
    }
}
