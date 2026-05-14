import Testing
import CoreFP
import DataStructure
@testable import SwiftRex

// MARK: - Shared fixtures

private struct GA: Sendable { var local: Int?; var other: String? }
private struct GS: Sendable { var local: Int = 0; var other: Int = 99 }
private struct GE: Sendable { var sub: Int = 0; var other: String = "" }

private let anySource = ActionSource(file: #file, function: #function, line: #line)

@MainActor
private func dispatch<A, S, E>(
    _ middleware: Middleware<A, S, E>,
    action: A,
    state: S,
    env: E
) -> Effect<A> {
    let dispatched = DispatchedAction(action, dispatcher: anySource)
    let access = StateAccess<S> { state }
    return middleware.handle(dispatched, access).runReader(env)
}

@MainActor
private func actions<A: Sendable, S, E>(
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
            Reader { _ in .just(action.action * 2) }
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
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action.action) } }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action.action * 10) } }
        #expect(actions(Middleware.combine(lhs, rhs), action: 2, state: 0, env: ()).sorted() == [2, 20])
    }

    @Test func combineBothSeeTheSameAction() {
        let seen = LockProtected([Int]())
        let lhs = Middleware<Int, Int, Void>.handle { action, _ in
            Reader { _ in seen.mutate { $0.append(action.action) }; return .empty }
        }
        let rhs = Middleware<Int, Int, Void>.handle { action, _ in
            Reader { _ in seen.mutate { $0.append(action.action) }; return .empty }
        }
        _ = actions(Middleware.combine(lhs, rhs), action: 7, state: 0, env: ())
        #expect(seen.value == [7, 7])
    }

    @Test func leftIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action.action) } }
        #expect(actions(Middleware.combine(.identity, m), action: 5, state: 0, env: ()) == [5])
    }

    @Test func rightIdentityLaw() {
        let m = Middleware<Int, Int, Void>.handle { action, _ in Reader { _ in .just(action.action) } }
        #expect(actions(Middleware.combine(m, .identity), action: 5, state: 0, env: ()) == [5])
    }
}

// MARK: - liftAction

@Suite("Middleware liftAction")
@MainActor
struct MiddlewareLiftActionTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let doubler = Middleware<Int, Int, Void>.handle { action, _ in
        Reader { _ in .just(action.action * 2) }
    }

    @Test func matchingActionReachesMiddleware() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: 4, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(sut.handle(dispatched, StateAccess { 0 }).runReader(())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.first?.local == 8)
    }

    @Test func nonMatchingActionProducesEmptyEffect() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: nil, other: "x"), dispatcher: anySource)
        let effect = sut.handle(dispatched, StateAccess { 0 }).runReader(())
        #expect(effect.components.isEmpty)
    }

    @Test func outputActionIsWrappedViaReview() {
        let sut = doubler.liftAction(prism)
        let dispatched = DispatchedAction(GA(local: 3, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(sut.handle(dispatched, StateAccess { 0 }).runReader(())) { d in
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
        Reader { _ in
            guard let s = stateAccess.snapshotState() else { return .empty }
            return .just(s)
        }
    }

    @Test func liftStateClosureProjectsSubState() {
        let sut = statePasser.liftState { (gs: GS) in gs.local }
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(dispatched, StateAccess { GS(local: 55, other: 0) }).runReader(())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [55])
    }

    @Test func liftStateLensProjectsSubState() {
        let lens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = statePasser.liftState(lens)
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(dispatched, StateAccess { GS(local: 77, other: 0) }).runReader(())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [77])
    }

    @Test func liftStatePrismReturnsNilWhenCaseInactive() {
        let prism = Prism<Int?, Int>(preview: { $0 }, review: { Optional($0) })
        let sut = statePasser.liftState(prism)
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(dispatched, StateAccess<Int?> { nil }).runReader(())) { d in
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
            Reader { env in .just(env) }
        }.liftEnvironment { (ge: GE) in ge.sub }
        let dispatched = DispatchedAction(0, dispatcher: anySource)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(dispatched, StateAccess { 0 }).runReader(GE(sub: 33, other: ""))) { d in
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
        Reader { _ in
            guard let s = stateAccess.snapshotState() else { return .empty }
            return .just(s)
        }
    }

    private let optionalIntAT = AffineTraversal<Int?, Int>(
        preview: { $0 },
        set: { _, v in Optional(v) }
    )

    @Test func liftStateATProjectsSubStateWhenFocusPresent() {
        let sut = statePasser.liftState(optionalIntAT)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(DispatchedAction(0, dispatcher: anySource), StateAccess<Int?> { .some(55) }).runReader(())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value == [55])
    }

    @Test func liftStateATReturnsNilWhenFocusAbsent() {
        let sut = statePasser.liftState(optionalIntAT)
        let received = LockProtected([Int]())
        subscribeAll(sut.handle(DispatchedAction(0, dispatcher: anySource), StateAccess<Int?> { nil }).runReader(())) { d in
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
        Reader { env in .just(action.action + env) }
    }

    @Test func liftAllThreeAxesClosure() {
        let sut = base.lift(
            action: prism,
            state: { (gs: GS) in gs.local },
            environment: { (ge: GE) in ge.sub }
        )
        let dispatched = DispatchedAction(GA(local: 2, other: nil), dispatcher: anySource)
        let received = LockProtected([GA]())
        subscribeAll(sut.handle(dispatched, StateAccess { GS() }).runReader(GE(sub: 3, other: ""))) { d in
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
        subscribeAll(sut.handle(dispatched, StateAccess { GS() }).runReader(GE(sub: 4, other: ""))) { d in
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
        let effect = sut.handle(dispatched, StateAccess { GS() }).runReader(GE(sub: 0, other: ""))
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
            return Reader { _ in
                let post = stateAccess.snapshotState() ?? 0
                return .just(pre + post)
            }
        }
        let reader = sut.handle(DispatchedAction(0, dispatcher: anySource), access)
        stateBox.set(10)   // mutate after handle captures pre-state
        let received = LockProtected([Int]())
        subscribeAll(reader.runReader(())) { d in received.mutate { $0.append(d.action) } }
        // pre=0, post=10 → 0+10=10
        #expect(received.value == [10])
    }
}
