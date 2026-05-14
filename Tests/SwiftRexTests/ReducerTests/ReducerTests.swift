import CoreFP
@testable import SwiftRex
import XCTest

final class ReducerTests: XCTestCase {
    // MARK: - Factories: (Action, inout State) -> Void

    func testInoutFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            if action == "inc" { state += 1 }
        }
        var state = 0
        sut.reduce("inc")(&state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop")(&state)
        XCTAssertEqual(state, 1)
    }

    // MARK: - Factories: (Action, State) -> State

    func testPureFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            action == "inc" ? state + 1 : state
        }
        var state = 0
        sut.reduce("inc")(&state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop")(&state)
        XCTAssertEqual(state, 1)
    }

    // MARK: - Factories: (Action) -> EndoMut<State>

    func testEndoMutFactory() {
        let sut = Reducer<String, Int>.reduce { action in
            EndoMut { state in if action == "inc" { state += 1 } }
        }
        var state = 0
        sut.reduce("inc")(&state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop")(&state)
        XCTAssertEqual(state, 1)
    }

    func testEndoMutFactoryStoreCallPattern() {
        // Verifies the exact pattern the Store uses: reduce(action).runEndoMut(&_state)
        let sut = Reducer<String, Int>.reduce { action in
            EndoMut { state in if action == "double" { state *= 2 } }
        }
        var state = 3
        sut.reduce("double").runEndoMut(&state)
        XCTAssertEqual(state, 6)
    }

    // MARK: - Factories: (Action) -> Endo<State>

    func testEndoFactory() {
        let sut = Reducer<String, Int>.reduce { action in
            Endo { state in action == "inc" ? state + 1 : state }
        }
        var state = 0
        sut.reduce("inc")(&state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop")(&state)
        XCTAssertEqual(state, 1)
    }

    func testEndoFactoryBridgesToEndoMut() {
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
            XCTAssertEqual(s1, s2, "Mismatch for action '\(action)'")
        }
    }

    // MARK: - Semigroup

    func testCombineRunsBothReducers() {
        let first = Reducer<Void, [Int]>.reduce { _, state in state.append(1) }
        let second = Reducer<Void, [Int]>.reduce { _, state in state.append(2) }
        var state: [Int] = []
        Reducer.combine(first, second).reduce(())(&state)
        XCTAssertEqual(state, [1, 2])
    }

    func testCombineSecondSeesFirstMutations() {
        let first = Reducer<Void, Int>.reduce { _, state in state = 10 }
        let second = Reducer<Void, Int>.reduce { _, state in state += 5 }
        var state = 0
        Reducer.combine(first, second).reduce(())(&state)
        XCTAssertEqual(state, 15)
    }

    func testCombineOrderMatters() {
        let multiply = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        let add = Reducer<Void, Int>.reduce { _, state in state += 3 }
        var s1 = 5
        Reducer.combine(multiply, add).reduce(())(&s1)
        XCTAssertEqual(s1, 13) // (5 * 2) + 3

        var s2 = 5
        Reducer.combine(add, multiply).reduce(())(&s2)
        XCTAssertEqual(s2, 16) // (5 + 3) * 2
    }

    // MARK: - Monoid

    func testIdentityIsNoop() {
        let sut = Reducer<String, Int>.identity
        var state = 42
        sut.reduce("anything")(&state)
        XCTAssertEqual(state, 42)
    }

    func testIdentityReturnsEndoMutIdentity() {
        // identity.reduce(action) must be EndoMut.identity — a no-op closure
        let sut = Reducer<String, Int>.identity
        var state = 99
        sut.reduce("x").runEndoMut(&state)
        XCTAssertEqual(state, 99)
    }

    func testCombineWithIdentityIsIdempotent() {
        let r = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let identity = Reducer<Void, Int>.identity
        var s1 = 0; Reducer.combine(r, identity).reduce(())(&s1)
        var s2 = 0; Reducer.combine(identity, r).reduce(())(&s2)
        var s3 = 0; r.reduce(())(&s3)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s2, s3)
    }

    // MARK: - DSL builder

    func testComposeDSL() {
        let sut = Reducer<Void, Int>.compose {
            Reducer<Void, Int>.reduce { _, state in state += 1 }
            Reducer<Void, Int>.reduce { _, state in state *= 2 }
        }
        var state = 3
        sut.reduce(())(&state)
        XCTAssertEqual(state, 8) // (3 + 1) * 2
    }

    func testComposeVariadic() {
        let a = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let b = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        var state = 3
        Reducer.compose(a, b).reduce(())(&state)
        XCTAssertEqual(state, 8)
    }

    func testComposeDSLEmptyProducesIdentity() {
        let sut = Reducer<String, Int>.compose { }
        var state = 7
        sut.reduce("x")(&state)
        XCTAssertEqual(state, 7)
    }
}
