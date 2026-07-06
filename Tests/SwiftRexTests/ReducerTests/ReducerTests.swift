// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

@Suite
struct ReducerTests {
    // MARK: - Factories: (Action, inout State) -> Void

    @Test func inoutFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            if action == "inc" { state += 1 }
        }
        var state = 0
        sut.reduce("inc")(&state)
        #expect(state == 1)
        sut.reduce("noop")(&state)
        #expect(state == 1)
    }

    // MARK: - Factories: (Action, State) -> State

    @Test func pureFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            action == "inc" ? state + 1 : state
        }
        var state = 0
        sut.reduce("inc")(&state)
        #expect(state == 1)
        sut.reduce("noop")(&state)
        #expect(state == 1)
    }

    // MARK: - Factories: (Action) -> EndoMut<State>

    @Test func endoMutFactory() {
        let sut = Reducer<String, Int>.reduce { action in
            EndoMut { state in if action == "inc" { state += 1 } }
        }
        var state = 0
        sut.reduce("inc")(&state)
        #expect(state == 1)
        sut.reduce("noop")(&state)
        #expect(state == 1)
    }

    @Test func endoMutFactoryStoreCallPattern() {
        // Verifies the exact pattern the Store uses: reduce(action).runEndoMut(&_state)
        let sut = Reducer<String, Int>.reduce { action in
            EndoMut { state in if action == "double" { state *= 2 } }
        }
        var state = 3
        sut.reduce("double").runEndoMut(&state)
        #expect(state == 6)
    }

    // MARK: - Factories: (Action) -> Endo<State>

    @Test func endoFactory() {
        let sut = Reducer<String, Int>.reduce { action in
            Endo { state in action == "inc" ? state + 1 : state }
        }
        var state = 0
        sut.reduce("inc")(&state)
        #expect(state == 1)
        sut.reduce("noop")(&state)
        #expect(state == 1)
    }

    @Test func endoFactoryBridgesToEndoMut() {
        // Endo factory and inout factory must produce the same results
        let endoSut = Reducer<String, Int>.reduce { action in
            Endo { state in action == "inc" ? state + 1 : state }
        }
        let inoutSut = Reducer<String, Int>.reduce { action, state in
            if action == "inc" { state += 1 }
        }
        for action in ["inc", "noop"] {
            var s1 = 5, s2 = 5
            endoSut.reduce(action)(&s1)
            inoutSut.reduce(action)(&s2)
            #expect(s1 == s2, "Mismatch for action '\(action)'")
        }
    }

    // MARK: - Semigroup

    @Test func combineRunsBothReducers() {
        let first = Reducer<Void, [Int]>.reduce { _, state in state.append(1) }
        let second = Reducer<Void, [Int]>.reduce { _, state in state.append(2) }
        var state: [Int] = []
        Reducer.combine(first, second).reduce(())(&state)
        #expect(state == [1, 2])
    }

    @Test func combineSecondSeesFirstMutations() {
        let first = Reducer<Void, Int>.reduce { _, state in state = 10 }
        let second = Reducer<Void, Int>.reduce { _, state in state += 5 }
        var state = 0
        Reducer.combine(first, second).reduce(())(&state)
        #expect(state == 15)
    }

    @Test func combineOrderMatters() {
        let multiply = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        let add = Reducer<Void, Int>.reduce { _, state in state += 3 }
        var s1 = 5
        Reducer.combine(multiply, add).reduce(())(&s1)
        #expect(s1 == 13) // (5 * 2) + 3

        var s2 = 5
        Reducer.combine(add, multiply).reduce(())(&s2)
        #expect(s2 == 16) // (5 + 3) * 2
    }

    // MARK: - Monoid

    @Test func identityIsNoop() {
        let sut = Reducer<String, Int>.identity
        var state = 42
        sut.reduce("anything")(&state)
        #expect(state == 42)
    }

    @Test func identityReturnsEndoMutIdentity() {
        // identity.reduce(action) must be EndoMut.identity — a no-op closure
        let sut = Reducer<String, Int>.identity
        var state = 99
        sut.reduce("x").runEndoMut(&state)
        #expect(state == 99)
    }

    @Test func combineWithIdentityIsIdempotent() {
        let r = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let identity = Reducer<Void, Int>.identity
        var s1 = 0; Reducer.combine(r, identity).reduce(())(&s1)
        var s2 = 0; Reducer.combine(identity, r).reduce(())(&s2)
        var s3 = 0; r.reduce(())(&s3)
        #expect(s1 == s2)
        #expect(s2 == s3)
    }

    // MARK: - DSL builder

    @Test func composeDSL() {
        let sut = Reducer<Void, Int>.compose {
            Reducer<Void, Int>.reduce { _, state in state += 1 }
            Reducer<Void, Int>.reduce { _, state in state *= 2 }
        }
        var state = 3
        sut.reduce(())(&state)
        #expect(state == 8) // (3 + 1) * 2
    }

    @Test func composeVariadic() {
        let a = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let b = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        var state = 3
        Reducer.compose(a, b).reduce(())(&state)
        #expect(state == 8)
    }

    @Test func composeDSLEmptyProducesIdentity() {
        let sut = Reducer<String, Int>.compose {}
        var state = 7
        sut.reduce("x")(&state)
        #expect(state == 7)
    }
}
