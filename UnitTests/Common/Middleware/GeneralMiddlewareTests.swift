@testable import SwiftRex
import XCTest

class GeneralMiddlewareTests: MiddlewareTestsBase {
    func testAnyMiddlewareEvent() {
        // Given
        let middlewareMock = MiddlewareMock()
        let sut = AnyMiddleware(middlewareMock)
        let event = Event1()
        let state = TestState()
        let getState = { state }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        middlewareMock.handleEventGetStateNextClosure = { event, getState, next in
            next(event, getState)
        }

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, middlewareMock.handleEventGetStateNextCallsCount)
        XCTAssertEqual(event, middlewareMock.handleEventGetStateNextReceivedArguments!.event as! Event1)
        XCTAssertEqual(state, middlewareMock.handleEventGetStateNextReceivedArguments!.getState())
    }

    func testAnyMiddlewareAction() {
        // Given
        let middlewareMock = MiddlewareMock()
        let sut = AnyMiddleware(middlewareMock)
        let action = Action1()
        let state = TestState()
        let getState = { state }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)
        middlewareMock.handleActionGetStateNextClosure = { action, getState, next in
            next(action, getState)
        }

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, middlewareMock.handleActionGetStateNextCallsCount)
        XCTAssertEqual(action, middlewareMock.handleActionGetStateNextReceivedArguments!.action as! Action1)
        XCTAssertEqual(state, middlewareMock.handleActionGetStateNextReceivedArguments!.getState())
    }

    func testRotationMiddlewareAction() {
        // Given
        let sut = AnyMiddleware(RotationMiddleware(name: "m1"))
        let state = TestState()
        let getState = { state }
        let originalAction = Action1()
        var action2 = Action2()
        action2.value = originalAction.value
        action2.name = "a1m1"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action2, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: originalAction, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

    func testRotationMiddlewareEvent() {
        // Given
        let sut = AnyMiddleware(RotationMiddleware(name: "m1"))
        let state = TestState()
        let getState = { state }
        let originalEvent = Event1()
        var event2 = Event2()
        event2.value = originalEvent.value
        event2.name = "e1m1"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event2, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: originalEvent, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

//    func testActionHandler() {
//        let rotationMiddleware = RotationMiddleware(name: "m1")
//        let subjectMock = CurrentValueSubject(currentValue: TestState())
//        let actionHandler = TestStore(subject: subjectMock.subject,
//                                      reducer: createReducerMock().0,
//                                      middleware: rotationMiddleware)
//        let sut = AnyMiddleware(rotationMiddleware)
//
//        XCTAssert(actionHandler === sut.handlers.actionHandler)
//        XCTAssert(actionHandler === rotationMiddleware.actionHandler)
//    }
}
