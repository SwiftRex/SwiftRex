// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
@testable import SwiftRex

// Building-block generators over `Int` actions/states for the algebraic law suites.

let smallInt: Gen<SplitMix64, Int> = Gen.int(in: -5...5)

// Affine `s = s*a + b`. Composition of affine maps is non-commutative, so this can actually
// detect a broken `combine` (purely additive ops would pass even a wrong composition order).
let endoMutGen: Gen<SplitMix64, EndoMut<Int>> = Gen.zip(Gen.int(in: -3...3), Gen.int(in: -3...3)).map { pair in
    let (a, b) = pair
    return EndoMut { $0 = $0 &* a &+ b }
}

// A mix of `.unchanged` and `.mutation(...)`, weighted toward real mutations.
let reducerOutcomeGen: Gen<SplitMix64, ReducerOutcome<Int>> = Gen.frequency(NonEmpty(
    head: (1, Gen<SplitMix64, ReducerOutcome<Int>> { _ in .unchanged }),
    tail: [(3, endoMutGen.map { ReducerOutcome.mutation($0) })]
))

// Reducer `s = s*a + b*action` — depends on the action and is non-commutative under composition.
let reducerGen: Gen<SplitMix64, Reducer<Int, Int>> = Gen.zip(Gen.int(in: -3...3), Gen.int(in: -3...3)).map { pair in
    let (a, b) = pair
    return Reducer.reduce { action, state in state = state &* a &+ (b &* action) }
}

// Affine `x -> x*a + b` total functions, for functor map/composition laws.
let intFuncGen: Gen<SplitMix64, @Sendable (Int) -> Int> = Gen.zip(Gen.int(in: -3...3), Gen.int(in: -3...3)).map { pair in
    let (a, b) = pair
    return { $0 &* a &+ b }
}

// Partial functions (`nil` for odd inputs), for compactMap/Kleisli-composition laws.
let intKleisliGen: Gen<SplitMix64, @Sendable (Int) -> Int?> = Gen.zip(Gen.int(in: -3...3), Gen.int(in: -3...3)).map { pair in
    let (a, b) = pair
    return { value in value.isMultiple(of: 2) ? Optional(value &* a &+ b) : nil }
}

// An effect emitting a short (possibly empty) list of actions.
let effectGen: Gen<SplitMix64, Effect<Int>> = Gen.int(in: -10...10).array(ofCount: Gen.int(in: 0...3)).map { actions in
    Effect.sequence(actions)
}

/// Synchronously collects every action a (synchronous) effect emits — for observational equality
/// of non-`Equatable` `Effect` values.
func emitted(_ effect: Effect<Int>) -> [Int] {
    let box = LockProtected([Int]())
    subscribeAll(effect, send: { dispatched in box.mutate { $0.append(dispatched.action) } })
    return box.value
}
