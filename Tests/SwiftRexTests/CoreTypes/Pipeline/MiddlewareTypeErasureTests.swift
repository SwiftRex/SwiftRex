import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTypeErasureTests: XCTestCase {
    func testAnyMiddlewareReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        middleware.eraseToAnyMiddleware().receiveContext(getState: { TestState() }, output: .init { _, _ in })
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(0, middleware.handleActionFromAfterReducerCallsCount)
    }

    func testAnyMiddlewareHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionFromAfterReducerClosure = { action, dispatcher, afterReducer in
            afterReducer = .do { calledAfterReducer.fulfill() }
        }
        let erased = middleware.eraseToAnyMiddleware()
        erased.receiveContext(getState: { TestState() }, output: .init { _, _ in })
        var afterReducer: AfterReducer = .doNothing()
        erased.handle(action: .bar(.alpha), from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(1, middleware.handleActionFromAfterReducerCallsCount)
    }

    func testAnyMiddlewareContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let action = AppAction.bar(.charlie)
        let receivedAction = expectation(description: "action should have been received")

        let typeErased = middleware.eraseToAnyMiddleware()
        typeErased.receiveContext(
            getState: { state },
            output: .init { actionReceived, dispatcher in
                XCTAssertEqual(action, actionReceived)
                XCTAssertEqual("file_1", dispatcher.file)
                XCTAssertEqual("function_1", dispatcher.function)
                XCTAssertEqual(666, dispatcher.line)
                XCTAssertEqual("info_1", dispatcher.info)
                receivedAction.fulfill()
            }
        )
        middleware.receiveContextGetStateOutputReceivedArguments?.output.dispatch(
            action,
            from: .init(file: "file_1", function: "function_1", line: 666, info: "info_1")
        )

        XCTAssertEqual(state.value, middleware.receiveContextGetStateOutputReceivedArguments?.getState().value)
        wait(for: [receivedAction], timeout: 0.1)
    }
}
