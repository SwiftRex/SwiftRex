import Foundation
@testable import SwiftRex
import XCTest

class ReducerTests: XCTestCase {
    func testAnyReducer() {
        // Given
        let (sut, reducerMock) = createReducerMock()
        let action = Action1()
        let stateBefore = TestState()
        let stateExpected = TestState()
        reducerMock.reduceActionReturnValue = stateExpected

        // Then
        let stateAfter = sut.reduce(stateBefore, action)

        // Expect
        XCTAssertEqual(1, reducerMock.reduceActionCallsCount)
        XCTAssertNotEqual(stateExpected, stateBefore)
        XCTAssertEqual(stateExpected, stateAfter)
        XCTAssertEqual(action, reducerMock.reduceActionReceivedArguments!.action as! Action1)
        XCTAssertEqual(stateBefore, reducerMock.reduceActionReceivedArguments!.currentState)
    }

    func testNameReducerAction1() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, Action1())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("action1", state.name)
    }

    func testNameReducerAction2() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, Action2())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("action2", state.name)
    }

    func testNameReducerAction3() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, Action3())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("", state.name)
        XCTAssertEqual(previousState, state)
    }

    func testComposeTwoReducers() {
        let reducer1: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "2"
            return state
        }

        let sut = reducer1 <> reducer2

        let result = sut.reduce(TestState(value: UUID(), name: "0"), Action1())

        XCTAssertEqual("012", result.name)
    }

    func testComposeThreeReducers() {
        let reducer1: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "2"
            return state
        }

        let reducer3: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "3"
            return state
        }

        let sut = reducer1 <> reducer2 <> reducer3

        let result = sut.reduce(TestState(value: UUID(), name: "0"), Action1())

        XCTAssertEqual("0123", result.name)
    }

    func testComposeTwoGroupsOfReducers() {
        let reducer1: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "2"
            return state
        }

        let reducer3: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "3"
            return state
        }

        let reducer4: Reducer<TestState> = Reducer { state, _ in
            var state = state
            state.name += "4"
            return state
        }

        let sut = (reducer1 <> reducer2) <> (reducer3 <> reducer4)

        let result = sut.reduce(TestState(value: UUID(), name: "0"), Action1())

        XCTAssertEqual("01234", result.name)
    }

    func testEmptyReducer() {
        let original = TestState()
        let reducer = Reducer<TestState>.empty
        let reduced = reducer.reduce(original, Action1())

        XCTAssertEqual(original, reduced)
    }

    func testLiftReducer() {
        let original = TestState(value: UUID(), name: "a")
        let reducer = Reducer<String> { state, _ in
            state + "b"
        }

        let reduced = reducer.lift(\TestState.name).reduce(original, Action1())

        XCTAssertEqual(original.value, reduced.value)
        XCTAssertEqual("ab", reduced.name)
    }

    func testComposeTwoLiftedReducers() {
        let uuidBefore = UUID()
        let uuidAfter = UUID()

        let original = TestState(value: uuidBefore, name: "a")

        let reducerValue = Reducer<UUID> { state, _ in
            XCTAssertEqual(uuidBefore, state)
            return uuidAfter
        }

        let reducerName = Reducer<String> { state, _ in
            state + "b"
        }

        let reducer =
            reducerValue.lift(\TestState.value)
                <> reducerName.lift(\TestState.name)

        let reduced = reducer.reduce(original, Action1())

        XCTAssertEqual(uuidAfter, reduced.value)
        XCTAssertEqual("ab", reduced.name)
    }
}
