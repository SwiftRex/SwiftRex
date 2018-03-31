@testable import SwiftRex
import XCTest

class ReducerTests: XCTestCase {
    func testAnyReducer() {
        // Given
        let reducerMock = ReducerMock()
        let sut = AnyReducer(reducerMock)
        let action = Action1()
        let stateBefore = TestState()
        let stateExpected = TestState()
        reducerMock.reduceActionReturnValue = stateExpected

        // Then
        let stateAfter = sut.reduce(stateBefore, action: action)

        // Expect
        XCTAssertEqual(1, reducerMock.reduceActionCallsCount)
        XCTAssertNotEqual(stateExpected, stateBefore)
        XCTAssertEqual(stateExpected, stateAfter)
        XCTAssertEqual(action, reducerMock.reduceActionReceivedArguments!.action as! Action1)
        XCTAssertEqual(stateBefore, reducerMock.reduceActionReceivedArguments!.currentState)
    }

    func testNameReducerAction1() {
        // Given
        let sut = AnyReducer(NameReducer())
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, action: Action1())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("action1", state.name)
    }

    func testNameReducerAction2() {
        // Given
        let sut = AnyReducer(NameReducer())
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, action: Action2())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("action2", state.name)
    }

    func testNameReducerAction3() {
        // Given
        let sut = AnyReducer(NameReducer())
        let previousState = TestState()

        // Then
        let state = sut.reduce(previousState, action: Action3())

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("", state.name)
        XCTAssertEqual(previousState, state)
    }
}
