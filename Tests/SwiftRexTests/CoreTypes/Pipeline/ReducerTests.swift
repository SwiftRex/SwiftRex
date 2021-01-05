import Foundation
@testable import SwiftRex
import XCTest

// swiftlint:disable:next type_body_length
class ReducerTests: XCTestCase {
    func testAnyReducer() {
        // Given
        let (sut, reducerMock) = createReducerMock()
        let action = AppAction.foo
        let stateBefore = TestState()
        let stateExpected = TestState()
        reducerMock.reduceReturnValue = stateExpected

        // Then
        var stateAfter = stateBefore
        sut.reduce(action, &stateAfter)

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
        var state = previousState
        sut.reduce(.foo, &state)

        // Expect
        XCTAssertEqual(previousState.value, state.value)
        XCTAssertEqual("foo", state.name)
    }

    func testNameReducerActionBarAlpha() {
        // Given
        let sut = createNameReducer()
        let previousState = TestState()

        // Then
        var state = previousState
        sut.reduce(.bar(.alpha), &state)

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

        var result = TestState(value: UUID(), name: "0")
        sut.reduce(.foo, &result)

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

        var result = TestState(value: UUID(), name: "0")
        sut.reduce(.foo, &result)

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

        var result = TestState(value: UUID(), name: "0")
        sut.reduce(.foo, &result)

        XCTAssertEqual("01234", result.name)
    }

    func testEmptyReducer() {
        let original = TestState()
        let reducer = Reducer<AppAction, TestState>.identity
        var reduced = original
        reducer.reduce(.foo, &reduced)

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
                actionGetter: { $0.bar },
                stateGetter: { $0.name },
                stateSetter: { global, string in
                    global.name = string
                }
        )

        var reduced = original
        liftedReducer.reduce(.bar(.charlie), &reduced)

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
                actionGetter: { $0.bar },
                stateGetter: { $0.name },
                stateSetter: { global, string in
                    global.name = string
                }
        )

        var reduced = original
        liftedReducer.reduce(.foo, &reduced)

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

        var reduced = original
        liftedReducer.reduce(.bar(.charlie), &reduced)

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

        var reduced = original
        liftedReducer.reduce(.foo, &reduced)

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

        let reduced = actions.reduce(into: original) { accumulatedState, currentAction in
            reducerChain.reduce(currentAction, &accumulatedState)
        }

        XCTAssertEqual("a-foo-alpha-foo--bravo--foo", reduced.name)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testLiftReducerToCollectionIdentifiableRelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { action, state in
            .init(id: state.id, name: state.name + "_" + action)
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(action: \.somethingScopedById, stateCollection: \.list)

        var reduced = original
        liftedReducer.reduce(.somethingScopedById(.init(id: 2, action: "first")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 5, action: "second")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 6, action: "no_item")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 1, action: "third")), &reduced)

        XCTAssertEqual(original.testState, reduced.testState)
        XCTAssertEqual([
            .init(id: 1, name: "a_third"),
            .init(id: 2, name: "b_first"),
            .init(id: 4, name: "d"),
            .init(id: 3, name: "c"),
            .init(id: 5, name: "e_second")
        ], reduced.list)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testLiftReducerToCollectionIdentifiableIrrelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { _, state in
            XCTFail("This reducer should not be called for this action")
            return state
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(action: \.somethingScopedById, stateCollection: \.list)

        var reduced = original
        liftedReducer.reduce(.somethingScopedById(.init(id: 6, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 9, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)

        XCTAssertEqual(original, reduced)
    }

    func testLiftReducerToCollectionKeyPathIdentifierRelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { action, state in
            .init(id: state.id, name: state.name + "_" + action)
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(
                action: \.somethingScopedById,
                stateCollection: \.list,
                identifier: \.id
            )

        var reduced = original
        liftedReducer.reduce(.somethingScopedById(.init(id: 2, action: "first")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 5, action: "second")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 6, action: "no_item")), &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 1, action: "third")), &reduced)

        XCTAssertEqual(original.testState, reduced.testState)
        XCTAssertEqual([
            .init(id: 1, name: "a_third"),
            .init(id: 2, name: "b_first"),
            .init(id: 4, name: "d"),
            .init(id: 3, name: "c"),
            .init(id: 5, name: "e_second")
        ], reduced.list)
    }

    func testLiftReducerToCollectionKeyPathIdentifierIrrelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { _, state in
            XCTFail("This reducer should not be called for this action")
            return state
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(
                action: \.somethingScopedById,
                stateCollection: \.list,
                identifier: \.id
            )

        var reduced = original
        liftedReducer.reduce(.somethingScopedById(.init(id: 6, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.somethingScopedById(.init(id: 9, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)

        XCTAssertEqual(original, reduced)
    }

    func testLiftReducerToCollectionIndexedRelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { action, state in
            .init(id: state.id, name: state.name + "_" + action)
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(action: \.somethingScopedByIndex, stateCollection: \.list)

        var reduced = original
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 1, action: "first")), &reduced)
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 4, action: "second")), &reduced)
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 5, action: "no_item")), &reduced)
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 0, action: "third")), &reduced)

        XCTAssertEqual(original.testState, reduced.testState)
        XCTAssertEqual([
            .init(id: 1, name: "a_third"),
            .init(id: 2, name: "b_first"),
            .init(id: 4, name: "d"),
            .init(id: 3, name: "c"),
            .init(id: 5, name: "e_second")
        ], reduced.list)
    }

    func testLiftReducerToCollectionIndexedIrrelevantAction() {
        let original = AppState(
            testState: TestState(value: UUID(), name: "a"),
            list: [
                .init(id: 1, name: "a"),
                .init(id: 2, name: "b"),
                .init(id: 4, name: "d"),
                .init(id: 3, name: "c"),
                .init(id: 5, name: "e")
            ]
        )

        let reducer = Reducer<String, AppState.Item> { _, state in
            XCTFail("This reducer should not be called for this action")
            return state
        }

        let liftedReducer: Reducer<ActionForScopedTests, AppState> = reducer
            .liftToCollection(action: \.somethingScopedByIndex, stateCollection: \.list)

        var reduced = original
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 5, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)
        liftedReducer.reduce(.somethingScopedByIndex(.init(index: 8, action: "no_item")), &reduced)
        liftedReducer.reduce(.toIgnore, &reduced)

        XCTAssertEqual(original, reduced)
    }
}
