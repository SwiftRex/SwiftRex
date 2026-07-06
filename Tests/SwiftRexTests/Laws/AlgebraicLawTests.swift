// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

// Observational algebraic-law checks: these types are not `Equatable` (they wrap closures), so
// each law is verified by running the composed value against generated inputs and comparing
// outputs — final state for the mutation algebras, emitted actions for `Effect`.

@Suite("ReducerOutcome — Monoid laws")
struct ReducerOutcomeLawTests {
    private func run(_ outcome: ReducerOutcome<Int>, from state: Int) -> Int {
        var state = state
        outcome.runEndoMut(&state)
        return state
    }

    @Test func associativity() {
        forAll(reducerOutcomeGen, reducerOutcomeGen, reducerOutcomeGen, smallInt) { a, b, c, state in
            run(.combine(.combine(a, b), c), from: state) == run(.combine(a, .combine(b, c)), from: state)
        }
    }

    @Test func leftIdentity() {
        forAll(reducerOutcomeGen, smallInt) { a, state in
            run(.combine(.identity, a), from: state) == run(a, from: state)
        }
    }

    @Test func rightIdentity() {
        forAll(reducerOutcomeGen, smallInt) { a, state in
            run(.combine(a, .identity), from: state) == run(a, from: state)
        }
    }
}

@Suite("Reducer — Monoid laws")
struct ReducerLawTests {
    private func run(_ reducer: Reducer<Int, Int>, action: Int, from state: Int) -> Int {
        var state = state
        reducer.reduce(action)(&state)
        return state
    }

    @Test func associativity() {
        forAll(reducerGen, reducerGen, reducerGen, smallInt, smallInt) { a, b, c, action, state in
            run(.combine(.combine(a, b), c), action: action, from: state)
                == run(.combine(a, .combine(b, c)), action: action, from: state)
        }
    }

    @Test func leftIdentity() {
        forAll(reducerGen, smallInt, smallInt) { reducer, action, state in
            run(.combine(.identity, reducer), action: action, from: state) == run(reducer, action: action, from: state)
        }
    }

    @Test func rightIdentity() {
        forAll(reducerGen, smallInt, smallInt) { reducer, action, state in
            run(.combine(reducer, .identity), action: action, from: state) == run(reducer, action: action, from: state)
        }
    }
}

@Suite("Effect — Monoid & Functor laws")
struct EffectLawTests {
    @Test func associativity() {
        forAll(effectGen, effectGen, effectGen) { a, b, c in
            emitted(.combine(.combine(a, b), c)) == emitted(.combine(a, .combine(b, c)))
        }
    }

    @Test func leftIdentity() {
        forAll(effectGen) { a in emitted(.combine(.identity, a)) == emitted(a) }
    }

    @Test func rightIdentity() {
        forAll(effectGen) { a in emitted(.combine(a, .identity)) == emitted(a) }
    }

    @Test func functorIdentity() {
        let identity: @Sendable (Int) -> Int = { $0 }
        forAll(effectGen) { a in emitted(a.map(identity)) == emitted(a) }
    }

    @Test func functorComposition() {
        let f: @Sendable (Int) -> Int = { $0 &+ 1 }
        let g: @Sendable (Int) -> Int = { $0 &* 2 }
        forAll(effectGen) { a in emitted(a.map(f).map(g)) == emitted(a.map { g(f($0)) }) }
    }
}
