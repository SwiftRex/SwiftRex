@testable import SwiftRex
import XCTest

class BypassMiddlewareTests: MiddlewareTestsBase {
    func testBypassMiddlewareAction() {
        // Given
        let sut = BypassMiddleware<TestState>()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let action = ActionReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(0, actionHandler.triggerCallsCount)
    }

    func testBypassMiddlewareEvent() {
        // Given
        let sut = BypassMiddleware<TestState>()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(0, actionHandler.triggerCallsCount)
    }
}
