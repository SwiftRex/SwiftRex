import Foundation
@testable import SwiftRex
import XCTest

class ReducerTests: XCTestCase {
    func testAnyReducer() {
        // Given
        let (sut, reducerMock) = createReducerMock()
        let action = AppAction.foo
        let stateBefore = TestState()
        let stateExpected = TestState()
        reducerMock.reduceReturnValue = stateExpected

        // Then
        let stateAfter = sut.reduce(action, stateBefore)

        // Expect
        XCTAssertEqual(1, reducerMock.reduceCallsCount)
        XCTAssertNotEqual(stateExpected, stateBefore)
        XCTAssertEqual(stateExpected, stateAfter)
        XCTAssertEqual(action, reducerMock.reduceReceivedArguments!.action)
        XCTAssertEqual(stateBefore, reducerMock.reduceReceivedArguments!.currentState)
    }

    func testNameReducerActionFoo() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        let state = sut.reduce(.foo, previousState)

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("foo", state.name)
    }

    func testNameReducerActionBarAlpha() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        let state = sut.reduce(.bar(.alpha), previousState)

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("alpha", state.name)
    }

    func testComposeTwoReducers() {
        let reducer1: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "2"
            return state
        }

        let sut = reducer1 <> reducer2

        let result = sut.reduce(.foo, TestState(value: UUID(), name: "0"))

        XCTAssertEqual("012", result.name)
    }

    func testComposeThreeReducers() {
        let reducer1: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "2"
            return state
        }

        let reducer3: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "3"
            return state
        }

        let sut = reducer1 <> reducer2 <> reducer3

        let result = sut.reduce(.foo, TestState(value: UUID(), name: "0"))

        XCTAssertEqual("0123", result.name)
    }

    func testComposeTwoGroupsOfReducers() {
        let reducer1: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "1"
            return state
        }

        let reducer2: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "2"
            return state
        }

        let reducer3: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "3"
            return state
        }

        let reducer4: Reducer<AppAction, TestState> = Reducer { _, state in
            var state = state
            state.name += "4"
            return state
        }

        let sut = (reducer1 <> reducer2) <> (reducer3 <> reducer4)

        let result = sut.reduce(.foo, TestState(value: UUID(), name: "0"))

        XCTAssertEqual("01234", result.name)
    }

    func testEmptyReducer() {
        let original = TestState()
        let reducer = Reducer<AppAction, TestState>.identity
        let reduced = reducer.reduce(.foo, original)

        XCTAssertEqual(original, reduced)
    }

    func testLiftReducerRelevantAction() {
        let original = TestState(value: UUID(), name: "a")
        let reducer = Reducer<AppAction.Bar, String> { action, state in
            XCTAssertEqual(action, .charlie)
            return state + "b"
        }

        let liftedReducer: Reducer<AppAction, TestState> = reducer
            .lift(
                actionPrismGetter: { $0.bar },
                stateLensGetter: { $0.name },
                stateLensSetter: { global, string in
                    global.name = string
                }
        )

        let reduced = liftedReducer.reduce(.bar(.charlie), original)

        XCTAssertEqual(original.value, reduced.value)
        XCTAssertEqual("ab", reduced.name)
    }

    func testLiftReducerIrrelevantAction() {
        let original = TestState(value: UUID(), name: "a")
        let reducer = Reducer<AppAction.Bar, String> { _, state in
            XCTFail("This reducer should not be called for this action")
            return state + "b"
        }

        let liftedReducer: Reducer<AppAction, TestState> = reducer
            .lift(
                actionPrismGetter: { $0.bar },
                stateLensGetter: { $0.name },
                stateLensSetter: { global, string in
                    global.name = string
                }
        )

        let reduced = liftedReducer.reduce(.foo, original)

        XCTAssertEqual(original.value, reduced.value)
        XCTAssertEqual("a", reduced.name)
    }

    func testKeyPathLiftReducerRelevantAction() {
        let original = TestState(value: UUID(), name: "a")
        let reducer = Reducer<AppAction.Bar, String> { action, state in
            XCTAssertEqual(action, .charlie)
            return state + "b"
        }

        let liftedReducer: Reducer<AppAction, TestState> = reducer
            .lift(action: \.bar, state: \.name)

        let reduced = liftedReducer.reduce(.bar(.charlie), original)

        XCTAssertEqual(original.value, reduced.value)
        XCTAssertEqual("ab", reduced.name)
    }

    func testKeyPathReducerIrrelevantAction() {
        let original = TestState(value: UUID(), name: "a")
        let reducer = Reducer<AppAction.Bar, String> { _, state in
            XCTFail("This reducer should not be called for this action")
            return state + "b"
        }

        let liftedReducer: Reducer<AppAction, TestState> = reducer
            .lift(action: \.bar, state: \.name)

        let reduced = liftedReducer.reduce(.foo, original)

        XCTAssertEqual(original.value, reduced.value)
        XCTAssertEqual("a", reduced.name)
    }

    func testComposeLiftedReducers() {
        let original = TestState(value: UUID(), name: "a")

        let reducerGlobal = Reducer<AppAction, TestState> { _, state in
            var state = state
            state.name += "-"
            return state
        }

        let reducerFoo = Reducer<AppAction, String> { action, state in
            guard action == .foo else { return state }
            return state + "foo"
        }

        let reducerAlpha = Reducer<AppAction.Bar, String> { action, state in
            guard action == .alpha else { return state }
            return state + "alpha"
        }

        let reducerBravo = Reducer<AppAction.Bar, TestState> { action, state in
            guard action == .bravo else { return state }
            var state = state
            state.name += "bravo"
            return state
        }

        let reducerChain: Reducer<AppAction, TestState> =
            reducerGlobal
            <> reducerFoo.lift(state: \.name)
            <> reducerAlpha.lift(action: \.bar, state: \.name)
            <> reducerBravo.lift(action: \.bar)

        let actions = [AppAction.foo, .bar(.alpha), .foo, .bar(.echo), .bar(.bravo), .bar(.delta), .foo]
        let reduced = actions.reduce(original) { accumulatedState, currentAction in
            reducerChain.reduce(currentAction, accumulatedState)
        }

        XCTAssertEqual("a-foo-alpha-foo--bravo--foo", reduced.name)
    }
}
