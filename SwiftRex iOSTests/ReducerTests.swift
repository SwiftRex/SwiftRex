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

    func testComposeTwoAnyReducers() {
        let reducer1 = AnyReducer(ReducerMock())
        let reducer2 = AnyReducer(NameReducer())
        let sut = reducer1 >>> reducer2

        XCTAssertEqual(2, sut.reducers.count)
        XCTAssert(reducer1 === sut.reducers[0])
        XCTAssert(reducer2 === sut.reducers[1])
    }

    func testComposeThreeAnyReducers() {
        let reducer1 = AnyReducer(ReducerMock())
        let reducer2 = AnyReducer(NameReducer())
        let reducer3 = AnyReducer(NameReducer())
        let sut = reducer1 >>> reducer2 >>> reducer3

        XCTAssertEqual(3, sut.reducers.count)
        XCTAssert(reducer1 === sut.reducers[0])
        XCTAssert(reducer2 === sut.reducers[1])
        XCTAssert(reducer3 === sut.reducers[2])
    }

    func testComposeTwoGroupsOfAnyReducers() {
        let reducer1 = AnyReducer(ReducerMock())
        let reducer2 = AnyReducer(NameReducer())
        let reducer3 = AnyReducer(NameReducer())
        let reducer4 = AnyReducer(ReducerMock())
        let sut = (reducer1 >>> reducer2) >>> (reducer3 >>> reducer4)

        XCTAssertEqual(4, sut.reducers.count)
        XCTAssert(reducer1 === sut.reducers[0])
        XCTAssert(reducer2 === sut.reducers[1])
        XCTAssert(reducer3 === sut.reducers[2])
        XCTAssert(reducer4 === sut.reducers[3])
    }

    func testComposeTwoReducers() {
        let reducer1 = ReducerMock()
        let reducer2 = NameReducer()
        let sut = reducer1 >>> reducer2

        XCTAssertEqual(2, sut.reducers.count)
    }

    func testComposeThreeReducers() {
        let reducer1 = ReducerMock()
        let reducer2 = NameReducer()
        let reducer3 = NameReducer()
        let sut = reducer1 >>> reducer2 >>> reducer3

        XCTAssertEqual(3, sut.reducers.count)
    }

    func testComposeTwoGroupsOfReducers() {
        let reducer1 = ReducerMock()
        let reducer2 = NameReducer()
        let reducer3 = NameReducer()
        let reducer4 = ReducerMock()
        let sut = (reducer1 >>> reducer2) >>> (reducer3 >>> reducer4)

        XCTAssertEqual(4, sut.reducers.count)
    }
}
