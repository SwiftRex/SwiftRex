import DataStructure
@testable import SwiftRex
import Testing

// Law checks for the composite types, whose outcome has two observable halves: the final state
// (after the `ReducerOutcome` runs) and the actions the effect emits. Equality is on the pair.
//
// `Behavior`/`Middleware` `handle` and `PreReducerContext` are `@MainActor`, so the observation
// helpers run under `MainActor.assumeIsolated`; the suites are `@MainActor` so the tests really do
// run on the main actor (where that assumption holds).

private let anySource = ActionSource(file: "law.swift", function: "law()", line: 0)

// A behavior that both mutates (via a reducer) and emits a (captured) effect.
let behaviorGen: Gen<Behavior<Int, Int, Void>> = Gen.zip(reducerGen, effectGen).map { pair in
    let (reducer, effect) = pair
    return Behavior<Int, Int, Void>.handle { action, _ in
        .reduce { state in reducer.reduce(action)(&state) }
            .produce { _ in effect }
    }
}

let consequenceGen: Gen<Consequence<Int, Void, Int>> = Gen.zip(reducerOutcomeGen, effectGen).map { pair in
    let (outcome, effect) = pair
    return Consequence<Int, Void, Int>(mutation: outcome, effect: Reader { _ in effect })
}

let middlewareGen: Gen<Middleware<Int, Int, Void>> = effectGen.map { effect in
    Middleware<Int, Int, Void>.handle { _, _ in Reader { _ in effect } }
}

private func observe(consequence: Consequence<Int, Void, Int>, from state: Int) -> (Int, [Int]) {
    var state = state
    consequence.mutation.runEndoMut(&state)
    let post = PostReducerContext<Int, Void>(environment: (), getter: { state })
    return (state, emitted(consequence.effect.runReader(post)))
}

@Suite("Consequence — Monoid laws")
struct ConsequenceLawTests {
    @Test func associativity() {
        forAll(consequenceGen, consequenceGen, consequenceGen, smallInt) { a, b, c, state in
            observe(consequence: .combine(.combine(a, b), c), from: state)
                == observe(consequence: .combine(a, .combine(b, c)), from: state)
        }
    }

    @Test func leftIdentity() {
        forAll(consequenceGen, smallInt) { a, state in
            observe(consequence: .combine(.identity, a), from: state) == observe(consequence: a, from: state)
        }
    }

    @Test func rightIdentity() {
        forAll(consequenceGen, smallInt) { a, state in
            observe(consequence: .combine(a, .identity), from: state) == observe(consequence: a, from: state)
        }
    }
}

@Suite("Behavior — Monoid laws")
@MainActor
struct BehaviorLawTests {
    private func observe(_ behavior: Behavior<Int, Int, Void>, action: Int, from state: Int) -> (Int, [Int]) {
        let pre = PreReducerContext<Int>(source: anySource, getter: { state })
        let consequence = behavior.handle(action, pre)
        var state = state
        consequence.mutation.runEndoMut(&state)
        let post = PostReducerContext<Int, Void>(environment: (), getter: { state })
        return (state, emitted(consequence.effect.runReader(post)))
    }

    @Test func associativity() {
        forAll(behaviorGen, behaviorGen, behaviorGen, smallInt, smallInt) { a, b, c, action, state in
            self.observe(.combine(.combine(a, b), c), action: action, from: state)
                == self.observe(.combine(a, .combine(b, c)), action: action, from: state)
        }
    }

    @Test func leftIdentity() {
        forAll(behaviorGen, smallInt, smallInt) { behavior, action, state in
            self.observe(.combine(.identity, behavior), action: action, from: state)
                == self.observe(behavior, action: action, from: state)
        }
    }

    @Test func rightIdentity() {
        forAll(behaviorGen, smallInt, smallInt) { behavior, action, state in
            self.observe(.combine(behavior, .identity), action: action, from: state)
                == self.observe(behavior, action: action, from: state)
        }
    }
}

@Suite("Middleware — Monoid laws")
@MainActor
struct MiddlewareLawTests {
    private func observe(_ middleware: Middleware<Int, Int, Void>, action: Int, from state: Int) -> [Int] {
        let pre = PreReducerContext<Int>(source: anySource, getter: { state })
        let reader = middleware.handle(action, pre)
        let post = PostReducerContext<Int, Void>(environment: (), getter: { state })
        return emitted(reader.runReader(post))
    }

    @Test func associativity() {
        forAll(middlewareGen, middlewareGen, middlewareGen, smallInt, smallInt) { a, b, c, action, state in
            self.observe(.combine(.combine(a, b), c), action: action, from: state)
                == self.observe(.combine(a, .combine(b, c)), action: action, from: state)
        }
    }

    @Test func leftIdentity() {
        forAll(middlewareGen, smallInt, smallInt) { middleware, action, state in
            self.observe(.combine(.identity, middleware), action: action, from: state)
                == self.observe(middleware, action: action, from: state)
        }
    }

    @Test func rightIdentity() {
        forAll(middlewareGen, smallInt, smallInt) { middleware, action, state in
            self.observe(.combine(middleware, .identity), action: action, from: state)
                == self.observe(middleware, action: action, from: state)
        }
    }
}
