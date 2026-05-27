import CoreFP
@testable import SwiftRex
import Testing

// MARK: - Test helpers

@MainActor private func voidCtx<S>(state: S? = nil) -> PostReducerContext<S, Void> {
    PostReducerContext(environment: (), getter: { state })
}

@Suite("Consequence")
@MainActor
struct ConsequenceTests {
    // MARK: - doNothing / identity

    @Test func doNothingLeavesStateUnchanged() {
        var state = 42
        Consequence<Int, Void, Int>.doNothing.mutation.runEndoMut(&state)
        #expect(state == 42)
    }

    @Test func doNothingProducesNoEffect() {
        #expect(Consequence<Int, Void, Int>.doNothing.effect(voidCtx()).components.isEmpty)
    }

    @Test func identityIsDoNothing() {
        var state = 7
        Consequence<Int, Void, Int>.identity.mutation.runEndoMut(&state)
        #expect(state == 7)
        #expect(Consequence<Int, Void, Int>.identity.effect(voidCtx()).components.isEmpty)
    }

    // MARK: - reduce

    @Test func reduceMutatesState() {
        var state = 0
        Consequence<Int, Void, Never>.reduce { $0 += 10 }.mutation.runEndoMut(&state)
        #expect(state == 10)
    }

    @Test func reduceProducesNoEffect() {
        #expect(Consequence<Int, Void, Never>.reduce { $0 += 1 }.effect(voidCtx()).components.isEmpty)
    }

    // MARK: - produce

    @Test func produceLeavesStateUnchanged() {
        var state = 5
        Consequence<Int, Void, Int>.produce { _ in .just(99) }.mutation.runEndoMut(&state)
        #expect(state == 5)
    }

    @Test func produceDispatchesAction() {
        let c = Consequence<Int, Void, Int>.produce { _ in .just(42) }
        let received = LockProtected([Int]())
        subscribeAll(c.effect(voidCtx())) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [42])
    }

    @Test func produceReceivesEnvironment() {
        struct Env: Sendable { let value: Int }
        let c = Consequence<Int, Env, Int>.produce { ctx in .just(ctx.environment.value) }
        let received = LockProtected([Int]())
        subscribeAll(
            c.effect(PostReducerContext<Int, Env>(environment: Env(value: 7), getter: { nil }))
        ) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [7])
    }

    // MARK: - reduce + produce chaining

    @Test func chainReduceProduceMutatesAndEmitsEffect() {
        var state = 0
        let c = Consequence<Int, Void, Int>.reduce { $0 += 5 }.produce { _ in .just(99) }
        c.mutation.runEndoMut(&state)
        #expect(state == 5)
        let received = LockProtected([Int]())
        subscribeAll(c.effect(voidCtx())) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value == [99])
    }

    @Test func chainProduceProduceCombinesEffects() {
        let c = Consequence<Int, Void, Int>
            .produce { _ in .just(1) }
            .produce { _ in .just(2) }
        let received = LockProtected([Int]())
        subscribeAll(c.effect(voidCtx())) { d in received.mutate { $0.append(d.action) } }
        #expect(received.value.sorted() == [1, 2])
    }

    // MARK: - Semigroup / Monoid

    @Test func combineMutationsAreSequential() {
        var state = 0
        let lhs = Consequence<Int, Void, Never>.reduce { $0 += 1 }
        let rhs = Consequence<Int, Void, Never>.reduce { $0 *= 3 }
        Consequence.combine(lhs, rhs).mutation.runEndoMut(&state)
        #expect(state == 3) // (0+1)*3
    }

    @Test func combineEffectsAreMerged() {
        let lhs = Consequence<Int, Void, Int>.produce { _ in .just(10) }
        let rhs = Consequence<Int, Void, Int>.produce { _ in .just(20) }
        let received = LockProtected([Int]())
        subscribeAll(Consequence.combine(lhs, rhs).effect(voidCtx())) { d in
            received.mutate { $0.append(d.action) }
        }
        #expect(received.value.sorted() == [10, 20])
    }

    @Test func leftIdentityLaw() {
        var state = 5
        let c = Consequence<Int, Void, Never>.reduce { $0 += 1 }
        Consequence.combine(.identity, c).mutation.runEndoMut(&state)
        #expect(state == 6)
    }

    @Test func rightIdentityLaw() {
        var state = 5
        let c = Consequence<Int, Void, Never>.reduce { $0 += 1 }
        Consequence.combine(c, .identity).mutation.runEndoMut(&state)
        #expect(state == 6)
    }
}
