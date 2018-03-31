@testable import SwiftRex
import XCTest

class MiddlewareTests: XCTestCase {
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

    func testMiddlewareContainerAction() {
        // Given
        let sut = MiddlewareContainer<TestState>()
        ["m1", "m2"]
            .lazy
            .map(RotationMiddleware.init)
            .forEach(sut.append)
        let state = TestState()
        let getState = { state }
        let originalAction = Action1()
        var action3 = Action3()
        action3.value = originalAction.value
        action3.name = "a1m1m2"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action3, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: originalAction, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

    func testMiddlewareContainerEvent() {
        // Given
        let sut = MiddlewareContainer<TestState>()
        ["m1", "m2"]
            .lazy
            .map(RotationMiddleware.init)
            .forEach(sut.append)
        let state = TestState()
        let getState = { state }
        let originalEvent = Event1()
        var event3 = Event3()
        event3.value = originalEvent.value
        event3.name = "e1m1m2"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event3, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: originalEvent, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

    func testMiddlewareContainerOrderAction() {
        // Given
        let sut = MiddlewareContainer<TestState>()
        ["m1", "m2", "m3", "m4"]
            .lazy
            .map(RotationMiddleware.init)
            .forEach(sut.append)
        let state = TestState()
        let getState = { state }
        let originalAction = Action1()
        var action2 = Action2()
        action2.value = originalAction.value
        action2.name = "a1m1m2m3m4"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action2, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: originalAction, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

    func testMiddlewareContainerOrderEvent() {
        // Given
        let sut = MiddlewareContainer<TestState>()
        ["m1", "m2", "m3", "m4"]
            .lazy
            .map(RotationMiddleware.init)
            .forEach(sut.append)
        let state = TestState()
        let getState = { state }
        let originalEvent = Event1()
        var event2 = Event2()
        event2.value = originalEvent.value
        event2.name = "e1m1m2m3m4"
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event2, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: originalEvent, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
    }

    private func lastActionInChain<A: Action & Equatable>(_ action: A,
                                                          state: TestState,
                                                          expectation: XCTestExpectation)
        -> (Action, @escaping GetState<TestState>) -> Void {
        return { chainAction, chainStateGetter in
            XCTAssertEqual(action, chainAction as! A)
            XCTAssertEqual(state, chainStateGetter())
            expectation.fulfill()
        }
    }

    private func lastEventInChain<E: Event & Equatable>(_ event: E,
                                                          state: TestState,
                                                          expectation: XCTestExpectation)
        -> (Event, @escaping GetState<TestState>) -> Void {
            return { chainEvent, chainStateGetter in
                XCTAssertEqual(event, chainEvent as! E)
                XCTAssertEqual(state, chainStateGetter())
                expectation.fulfill()
            }
    }
}
