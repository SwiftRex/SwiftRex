@testable import SwiftRex
import XCTest

class SubstateMiddlewareTests: MiddlewareTestsBase {

    func testSubstateMiddlewareAction() {
        // Given
        let nameMiddleware = MiddlewareMock<String>()
        nameMiddleware.handleActionGetStateNextClosure = { [nameMiddleware] action, getState, next in
            XCTAssertEqual("name substate", getState())
            nameMiddleware.actionHandler!.trigger(Action1())
            nameMiddleware.actionHandler!.trigger(Action2())
            next(action, getState)
        }

        let sut = nameMiddleware.lift(\TestState.name)
        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState(value: UUID(), name: "name substate")
        let getState = { state }
        let action = ActionReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(2, actionHandler.triggerCallsCount)
        XCTAssertEqual(1, nameMiddleware.handleActionGetStateNextCallsCount)
        XCTAssertEqual(0, nameMiddleware.handleEventGetStateNextCallsCount)
        XCTAssert(nameMiddleware.actionHandler === sut.actionHandler)
    }

    func testSubstateMiddlewareEvent() {
        // Given
        let nameMiddleware = MiddlewareMock<String>()
        nameMiddleware.handleEventGetStateNextClosure = { [nameMiddleware] event, getState, next in
            XCTAssertEqual("name substate", getState())
            nameMiddleware.actionHandler!.trigger(Action1())
            nameMiddleware.actionHandler!.trigger(Action2())
            next(event, getState)
        }

        let sut = nameMiddleware.lift(\TestState.name)
        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState(value: UUID(), name: "name substate")
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(2, actionHandler.triggerCallsCount)
        XCTAssertEqual(0, nameMiddleware.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, nameMiddleware.handleEventGetStateNextCallsCount)
        XCTAssert(nameMiddleware.actionHandler === sut.actionHandler)
    }
}
