import Testing
import CoreFP
import DataStructure
@testable import SwiftRex

// MARK: - Shared fixtures

private struct GA: Sendable { var local: Int?; var other: String? }
private struct GS: Sendable { var local: Int = 0; var other: Int = 99 }

private let anySource = ActionSource(file: #file, function: #function, line: #line)

@MainActor
private func consequence(
    _ behavior: Behavior<Int, Int, Void>,
    action: Int,
    state: Int
) -> Consequence<Int, Void, Int> {
    behavior.handle(DispatchedAction(action, dispatcher: anySource), StateAccess { state })
}

@MainActor
private func receivedActions(
    _ behavior: Behavior<Int, Int, Void>,
    action: Int,
    state: Int
) -> [Int] {
    let c = consequence(behavior, action: action, state: state)
    let received = LockProtected([Int]())
    subscribeAll(c.effect.runReader(())) { d in received.mutate { $0.append(d.action) } }
    return received.value
}

// MARK: - Named constructors

@Suite("Behavior constructors")
@MainActor
struct BehaviorConstructorTests {
    @Test func handleClosureProducesConsequence() {
        let sut = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 += action.action } }
        var state = 0
        consequence(sut, action: 5, state: 0).mutation.runEndoMut(&state)
        #expect(state == 5)
    }
}

// MARK: - Reducer + Middleware init

@Suite("Behavior(reducer:middleware:)")
@MainActor
struct BehaviorReducerMiddlewareInitTests {
    private let reducer = Reducer<Int, Int>.reduce { action, state in state += action }
    private let middleware = Middleware<Int, Int, Void>.handle { action, _ in .just(action.action * 10) }

    @Test func reducerMutatesState() {
        let sut = Behavior(reducer: reducer, middleware: middleware)
        var state = 0
        consequence(sut, action: 3, state: 0).mutation.runEndoMut(&state)
        #expect(state == 3)
    }

    @Test func middlewareProducesEffect() {
        let sut = Behavior(reducer: reducer, middleware: middleware)
        #expect(receivedActions(sut, action: 2, state: 0) == [20])
    }
}

// MARK: - asBehavior (Reducer)

@Suite("Reducer.asBehavior")
@MainActor
struct ReducerAsBehaviorTests {
    private let reducer = Reducer<Int, Int>.reduce { action, state in state += action }

    @Test func mutatesState() {
        let sut: Behavior<Int, Int, Void> = reducer.asBehavior()
        var state = 0
        consequence(sut, action: 7, state: 0).mutation.runEndoMut(&state)
        #expect(state == 7)
    }

    @Test func producesNoEffect() {
        let sut: Behavior<Int, Int, Void> = reducer.asBehavior()
        #expect(receivedActions(sut, action: 1, state: 0).isEmpty)
    }
}

// MARK: - asBehavior (Middleware)

@Suite("Middleware.asBehavior")
@MainActor
struct MiddlewareAsBehaviorTests {
    private let middleware = Middleware<Int, Int, Void>.handle { action, _ in .just(action.action + 100) }

    @Test func leavesStateUnchanged() {
        var state = 42
        middleware.asBehavior.handle(
            DispatchedAction(1, dispatcher: anySource),
            StateAccess { 0 }
        ).mutation.runEndoMut(&state)
        #expect(state == 42)
    }

    @Test func producesEffect() {
        #expect(receivedActions(middleware.asBehavior, action: 5, state: 0) == [105])
    }
}

// MARK: - Monoid

@Suite("Behavior Monoid")
@MainActor
struct BehaviorMonoidTests {
    @Test func identityProducesDoNothing() {
        var state = 42
        consequence(Behavior<Int, Int, Void>.identity, action: 1, state: 0).mutation.runEndoMut(&state)
        #expect(state == 42)
        #expect(receivedActions(Behavior<Int, Int, Void>.identity, action: 1, state: 0).isEmpty)
    }

    @Test func combineMutationsAreSequential() {
        let lhs = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 += action.action } }
        let rhs = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 *= 2 } }
        let sut = Behavior.combine(lhs, rhs)
        var state = 0
        consequence(sut, action: 3, state: 0).mutation.runEndoMut(&state)
        #expect(state == 6) // (0+3)*2
    }

    @Test func combineEffectsAreMerged() {
        let lhs = Behavior<Int, Int, Void>.handle { action, _ in .produce { _ in .just(action.action) } }
        let rhs = Behavior<Int, Int, Void>.handle { action, _ in .produce { _ in .just(action.action * 10) } }
        #expect(receivedActions(Behavior.combine(lhs, rhs), action: 2, state: 0).sorted() == [2, 20])
    }

    @Test func combineBothSeePreMutationState() {
        let seen = LockProtected([Int]())
        let lhs = Behavior<Int, Int, Void>.handle { _, stateAccess in
            seen.mutate { $0.append(stateAccess.snapshotState() ?? -1) }
            return .reduce { $0 += 10 }
        }
        let rhs = Behavior<Int, Int, Void>.handle { _, stateAccess in
            seen.mutate { $0.append(stateAccess.snapshotState() ?? -1) }
            return .doNothing
        }
        _ = consequence(Behavior.combine(lhs, rhs), action: 0, state: 5)
        #expect(seen.value == [5, 5]) // both see pre-mutation state=5
    }

    @Test func leftIdentityLaw() {
        let b = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 += action.action } }
        var state = 0
        consequence(Behavior.combine(.identity, b), action: 4, state: 0).mutation.runEndoMut(&state)
        #expect(state == 4)
    }

    @Test func rightIdentityLaw() {
        let b = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 += action.action } }
        var state = 0
        consequence(Behavior.combine(b, .identity), action: 4, state: 0).mutation.runEndoMut(&state)
        #expect(state == 4)
    }
}

// MARK: - liftAction

@Suite("Behavior liftAction")
@MainActor
struct BehaviorLiftActionTests {
    private let prism = Prism<GA, Int>(preview: { $0.local }, review: { GA(local: $0, other: nil) })
    private let doubler = Behavior<Int, Int, Void>.handle { action, _ in
        .reduce { $0 += action.action }.produce { _ in .just(action.action * 2) }
    }

    @Test func matchingActionReachesHandler() {
        let sut = doubler.liftAction(prism)
        let c = sut.handle(DispatchedAction(GA(local: 3, other: nil), dispatcher: anySource), StateAccess { 0 })
        var state = 0
        c.mutation.runEndoMut(&state)
        #expect(state == 3)
    }

    @Test func nonMatchingActionProducesDoNothing() {
        let sut = doubler.liftAction(prism)
        let c = sut.handle(DispatchedAction(GA(local: nil, other: "x"), dispatcher: anySource), StateAccess { 0 })
        var state = 42
        c.mutation.runEndoMut(&state)
        #expect(state == 42)
        #expect(c.effect.runReader(()).components.isEmpty)
    }

    @Test func outputActionIsWrappedViaReview() {
        let sut = doubler.liftAction(prism)
        let c = sut.handle(DispatchedAction(GA(local: 4, other: nil), dispatcher: anySource), StateAccess { 0 })
        let received = LockProtected([GA]())
        subscribeAll(c.effect.runReader(())) { d in received.mutate { $0.append(d.action) } }
        // review(4*2) → GA(local: 8)
        #expect(received.value.first?.local == 8)
    }
}

// MARK: - liftState (KeyPath)

@Suite("Behavior liftState")
@MainActor
struct BehaviorLiftStateTests {
    private let adder = Behavior<Int, Int, Void>.handle { action, _ in .reduce { $0 += action.action } }

    @Test func liftStateKeyPathMutatesSubState() {
        let sut = adder.liftState(\GS.local)
        let c = sut.handle(DispatchedAction(5, dispatcher: anySource), StateAccess { GS() })
        var state = GS()
        c.mutation.runEndoMut(&state)
        #expect(state.local == 5)
        #expect(state.other == 99)
    }

    @Test func liftStateLensMutatesSubState() {
        let stateLens = Lens<GS, Int>(get: { $0.local }, set: { GS(local: $1, other: $0.other) })
        let sut = adder.liftState(stateLens)
        let c = sut.handle(DispatchedAction(7, dispatcher: anySource), StateAccess { GS() })
        var state = GS()
        c.mutation.runEndoMut(&state)
        #expect(state.local == 7)
        #expect(state.other == 99)
    }

    @Test func liftStateKeyPathStateAccessSeesSubState() {
        let seen = LockProtected([Int]())
        let observer = Behavior<Int, Int, Void>.handle { _, stateAccess in
            seen.mutate { $0.append(stateAccess.snapshotState() ?? -1) }
            return .doNothing
        }
        let sut = observer.liftState(\GS.local)
        _ = sut.handle(DispatchedAction(0, dispatcher: anySource), StateAccess { GS(local: 42, other: 0) })
        #expect(seen.value == [42])
    }
}
