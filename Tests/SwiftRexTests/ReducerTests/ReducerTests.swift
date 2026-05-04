import XCTest
@testable import SwiftRex

final class ReducerTests: XCTestCase {
    // MARK: - Factories

    func testInoutFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            if action == "inc" { state += 1 }
        }
        var state = 0
        sut.reduce("inc", &state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop", &state)
        XCTAssertEqual(state, 1)
    }

    func testPureFactory() {
        let sut = Reducer<String, Int>.reduce { action, state in
            action == "inc" ? state + 1 : state
        }
        var state = 0
        sut.reduce("inc", &state)
        XCTAssertEqual(state, 1)
        sut.reduce("noop", &state)
        XCTAssertEqual(state, 1)
    }

    // MARK: - Semigroup

    func testCombineRunsBothReducers() {
        let first = Reducer<Void, [Int]>.reduce { _, state in state.append(1) }
        let second = Reducer<Void, [Int]>.reduce { _, state in state.append(2) }
        let sut = Reducer.combine(first, second)
        var state: [Int] = []
        sut.reduce((), &state)
        XCTAssertEqual(state, [1, 2])
    }

    func testCombineSecondSeesFirstMutations() {
        let first = Reducer<Void, Int>.reduce { _, state in state = 10 }
        let second = Reducer<Void, Int>.reduce { _, state in state += 5 }
        let sut = Reducer.combine(first, second)
        var state = 0
        sut.reduce((), &state)
        XCTAssertEqual(state, 15)
    }

    func testCombineOrderMatters() {
        let multiply = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        let add = Reducer<Void, Int>.reduce { _, state in state += 3 }
        var state = 5

        var s1 = state
        Reducer.combine(multiply, add).reduce((), &s1)
        XCTAssertEqual(s1, 13) // (5 * 2) + 3

        var s2 = state
        Reducer.combine(add, multiply).reduce((), &s2)
        XCTAssertEqual(s2, 16) // (5 + 3) * 2
    }

    // MARK: - Monoid

    func testIdentityIsNoop() {
        let sut = Reducer<String, Int>.identity
        var state = 42
        sut.reduce("anything", &state)
        XCTAssertEqual(state, 42)
    }

    func testCombineWithIdentityIsIdempotent() {
        let r = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let identity = Reducer<Void, Int>.identity
        var s1 = 0; Reducer.combine(r, identity).reduce((), &s1)
        var s2 = 0; Reducer.combine(identity, r).reduce((), &s2)
        var s3 = 0; r.reduce((), &s3)
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
        sut.reduce((), &state)
        XCTAssertEqual(state, 8) // (3 + 1) * 2
    }

    func testComposeVariadic() {
        let a = Reducer<Void, Int>.reduce { _, state in state += 1 }
        let b = Reducer<Void, Int>.reduce { _, state in state *= 2 }
        let sut = Reducer.compose(a, b)
        var state = 3
        sut.reduce((), &state)
        XCTAssertEqual(state, 8)
    }

    func testComposeDSLEmptyProducesIdentity() {
        let sut = Reducer<String, Int>.compose { }
        var state = 7
        sut.reduce("x", &state)
        XCTAssertEqual(state, 7)
    }
}
