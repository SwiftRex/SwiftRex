@testable import SwiftRex
import XCTest

class GeneralMiddlewareTests: MiddlewareTestsBase {
    func testAnyMiddlewareHandlersGet() {
        // Given
        let middlewareMock = MiddlewareMock<TestState>()
        let sut = AnyMiddleware(middlewareMock)

        // When
        middlewareMock.handlers = .init(actionHandler: .init(), eventHandler: .init())

        // Then
        XCTAssertNotNil(sut.handlers)
    }

    func testAnyMiddlewareHandlersSet() {
        // Given
        let middlewareMock = MiddlewareMock<TestState>()
        let sut = AnyMiddleware(middlewareMock)

        // When
        sut.handlers = .init(actionHandler: .init(), eventHandler: .init())

        // Then
        XCTAssertNotNil(middlewareMock.handlers)
    }

    func testAnyMiddlewareEvent() {
        // Given
        let middlewareMock = MiddlewareMock<TestState>()
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
        let middlewareMock = MiddlewareMock<TestState>()
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

    func testMessageHandlerAction() {
        // Given
        let actions: [ActionProtocol] = [Action1(), Action3(), Action1(), Action2()]
        let middlewareMock = MiddlewareMock<TestState>()
        let rotationMiddleware = RotationMiddleware(name: "m1")
        let subjectMock = CurrentValueSubject(currentValue: TestState())
        let store = TestStore(subject: subjectMock.subject,
                              reducer: createReducerMock().0,
                              middleware: middlewareMock <> rotationMiddleware)

        var count = 0
        let shouldBeCalled4Times = expectation(description: "it should be called 4 times")
        middlewareMock.handleActionGetStateNextClosure = { action, _, _ in
            switch count {
            case 0:
                XCTAssertEqual(action as? Action1, actions[count] as? Action1)
            case 1:
                XCTAssertEqual(action as? Action3, actions[count] as? Action3)
            case 2:
                XCTAssertEqual(action as? Action1, actions[count] as? Action1)
            case 3:
                XCTAssertEqual(action as? Action2, actions[count] as? Action2)
                shouldBeCalled4Times.fulfill()
            default: XCTFail("Called more times than expected")
            }
            count += 1
        }

        // Then
        actions.forEach(rotationMiddleware.handlers.actionHandler.trigger)

        // Expect
        XCTAssertNotNil(store)
        wait(for: [shouldBeCalled4Times], timeout: 0.5)
    }

    func testMessageHandlerEvent() {
        // Given
        let events: [EventProtocol] = [Event1(), Event3(), Event1(), Event2()]
        let middlewareMock = MiddlewareMock<TestState>()
        let rotationMiddleware = RotationMiddleware(name: "m1")
        let subjectMock = CurrentValueSubject(currentValue: TestState())
        let store = TestStore(subject: subjectMock.subject,
                              reducer: createReducerMock().0,
                              middleware: middlewareMock <> rotationMiddleware)

        var count = 0
        let shouldBeCalled4Times = expectation(description: "it should be called 4 times")
        middlewareMock.handleEventGetStateNextClosure = { event, _, _ in
            switch count {
            case 0:
                XCTAssertEqual(event as? Action1, events[count] as? Action1)
            case 1:
                XCTAssertEqual(event as? Action3, events[count] as? Action3)
            case 2:
                XCTAssertEqual(event as? Action1, events[count] as? Action1)
            case 3:
                XCTAssertEqual(event as? Action2, events[count] as? Action2)
                shouldBeCalled4Times.fulfill()
            default: XCTFail("Called more times than expected")
            }
            count += 1
        }

        // Then
        events.forEach(rotationMiddleware.handlers.eventHandler.dispatch)

        // Expect
        XCTAssertNotNil(store)
        wait(for: [shouldBeCalled4Times], timeout: 0.5)
    }
}
