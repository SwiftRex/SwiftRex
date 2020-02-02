import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTypeErasureTests: XCTestCase {
    func testAnyMiddlewareReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        middleware.eraseToAnyMiddleware().receiveContext(getState: { TestState() }, output: .init { _ in })
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(0, middleware.handleActionCallsCount)
    }

    func testAnyMiddlewareHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionReturnValue = .do { calledAfterReducer.fulfill() }
        let erased = middleware.eraseToAnyMiddleware()
        erased.receiveContext(getState: { TestState() }, output: .init { _ in })
        erased.handle(action: .bar(.alpha)).reducerIsDone()
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(1, middleware.handleActionCallsCount)
    }

    func testAnyMiddlewareContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let action = AppAction.bar(.charlie)
        let receivedAction = expectation(description: "action should have been received")

        let typeErased = middleware.eraseToAnyMiddleware()
        typeErased.receiveContext(
            getState: { state },
            output: .init { actionReceived in
                XCTAssertEqual(action, actionReceived)
                receivedAction.fulfill()
            }
        )
        middleware.receiveContextGetStateOutputReceivedArguments?.output.dispatch(action)

        XCTAssertEqual(state.value, middleware.receiveContextGetStateOutputReceivedArguments?.getState().value)
        wait(for: [receivedAction], timeout: 0.1)
    }
}
