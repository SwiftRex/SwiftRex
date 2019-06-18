@testable import SwiftRex
import XCTest

class SubstateMiddlewareTests: MiddlewareTestsBase {
    func testSubstateMiddlewareHandlers() {
        // Given
        let nameMiddleware = MiddlewareMock<String>()
        let handlers = MessageHandlerMock()
        nameMiddleware.handlers = handlers.value
        let generalMiddleware = nameMiddleware.lift(\TestState.name)
        let action1 = Action1()
        let action2 = Action2()
        let event1 = Event1()
        let event2 = Event2()

        // When
        nameMiddleware.handlers.actionHandler.trigger(action1)
        nameMiddleware.handlers.eventHandler.dispatch(event1)
        generalMiddleware.handlers.actionHandler.trigger(action2)
        generalMiddleware.handlers.eventHandler.dispatch(event2)

        // Then
        XCTAssertEqual(2, handlers.actionHandlerMock.actions.count)
        XCTAssertEqual(action1, handlers.actionHandlerMock.actions[0] as? Action1)
        XCTAssertEqual(action2, handlers.actionHandlerMock.actions[1] as? Action2)
        XCTAssertEqual(2, handlers.eventHandlerMock.events.count)
        XCTAssertEqual(event1, handlers.eventHandlerMock.events[0] as? Event1)
        XCTAssertEqual(event2, handlers.eventHandlerMock.events[1] as? Event2)
    }

    func testSubstateMiddlewareAction() {
        // Given
        let nameMiddleware = MiddlewareMock<String>()
        nameMiddleware.handleActionGetStateNextClosure = { [nameMiddleware] action, getState, next in
            XCTAssertEqual("name substate", getState())
            nameMiddleware.handlers!.actionHandler.trigger(Action1())
            nameMiddleware.handlers!.actionHandler.trigger(Action2())
            next(action, getState)
        }

        let sut = nameMiddleware.lift(\TestState.name)
        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState(value: UUID(), name: "name substate")
        let getState = { state }
        let action = ActionReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(2, messageHandler.actionHandlerMock.actions.count)
        XCTAssertEqual(1, nameMiddleware.handleActionGetStateNextCallsCount)
        XCTAssertEqual(0, nameMiddleware.handleEventGetStateNextCallsCount)
    }

    func testSubstateMiddlewareEvent() {
        // Given
        let nameMiddleware = MiddlewareMock<String>()
        nameMiddleware.handleEventGetStateNextClosure = { [nameMiddleware] event, getState, next in
            XCTAssertEqual("name substate", getState())
            nameMiddleware.handlers.actionHandler.trigger(Action1())
            nameMiddleware.handlers.actionHandler.trigger(Action2())
            next(event, getState)
        }

        let sut = nameMiddleware.lift(\TestState.name)
        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState(value: UUID(), name: "name substate")
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(2, messageHandler.actionHandlerMock.actions.count)
        XCTAssertEqual(0, nameMiddleware.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, nameMiddleware.handleEventGetStateNextCallsCount)
    }
}
