@testable import SwiftRex
import XCTest

class StoreBaseTests: XCTestCase {

    func testStoreDispatchEvent() {
        // Given
        let event = Event1()
        let reducer = ReducerMock()
        let middleware1 = MiddlewareMock()
        let middleware2 = MiddlewareMock()
        middleware1.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
        }
        middleware2.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
        }
        let sut = TestStore(initialState: TestState(),
                            reducers: [reducer.reduce],
                            middlewares: [middleware1, middleware2])

        // Then
        sut.dispatch(event)

        // Expect
        XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, reducer.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
    }

    func testStoreTriggerAction() {
        // Given
        let action = Action1()
        let middleware1 = MiddlewareMock()
        let middleware2 = MiddlewareMock()
        let reducer = ReducerMock()
        middleware1.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        middleware2.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        reducer.reduceActionClosure = { reduceState, reduceAction in
            XCTAssertEqual(action, reduceAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, reducer.reduceActionCallsCount)
            XCTAssertEqual("", reduceState.name)

            return TestState(value: UUID(), name: "reduced")
        }
        let sut = TestStore(initialState: TestState(),
                            reducers: [reducer.reduce],
                            middlewares: [middleware1, middleware2])

        // Then
        sut.trigger(action)

        // Expect
        XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, reducer.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
    }
}
