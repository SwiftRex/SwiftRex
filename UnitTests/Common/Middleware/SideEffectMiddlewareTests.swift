@testable import SwiftRex
import XCTest

class SideEffectMiddlewareTests: MiddlewareTestsBase {
    func testSideEffectMiddlewareAction() {
        // Given
        let sut = SideEffectMiddlewareMock<TestState>()

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState()
        let getState = { state }
        let action = ActionReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 10)
        XCTAssertEqual(0, messageHandler.actionHandlerMock.actions.count)
    }

    func testSideEffectMiddlewareEvent() {
        // Given
        let sut = SideEffectMiddlewareMock<TestState>()

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock<TestState>()
        sideEffect.executeGetStateReturnValue = PublisherType(subscribe: { subscriber in
            subscriber.onValue(Action1())
            subscriber.onValue(Action2())
            subscriber.onValue(Action3())
            return FooSubscription()
        })

        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingAllowEventToPropagate = true

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(3, messageHandler.actionHandlerMock.actions.count)
        XCTAssertEqual("a1", (messageHandler.actionHandlerMock.actions[0] as! Action1).name)
        XCTAssertEqual("a2", (messageHandler.actionHandlerMock.actions[1] as! Action2).name)
        XCTAssertEqual("a3", (messageHandler.actionHandlerMock.actions[2] as! Action3).name)
    }

    func testSideEffectMiddlewareEventNoPropagation() {
        // Given
        let sut = SideEffectMiddlewareMock<TestState>()

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let sideEffect = SideEffectProducerMock<TestState>()
        sideEffect.executeGetStateReturnValue = PublisherType(subscribe: { subscriber in
            subscriber.onValue(Action1())
            subscriber.onValue(Action2())
            subscriber.onValue(Action3())
            return FooSubscription()
        })
        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingAllowEventToPropagate = false

        // Then
        sut.handle(event: event, getState: getState, next: { _, _ in XCTFail("It should be propagating") })

        // Expect
        XCTAssertEqual(3, messageHandler.actionHandlerMock.actions.count)
        XCTAssertEqual("a1", (messageHandler.actionHandlerMock.actions[0] as! Action1).name)
        XCTAssertEqual("a2", (messageHandler.actionHandlerMock.actions[1] as! Action2).name)
        XCTAssertEqual("a3", (messageHandler.actionHandlerMock.actions[2] as! Action3).name)
    }

    func testSideEffectMiddlewareUnknownEvent() {
        // Given
        let sut = SideEffectMiddlewareMock<TestState>()

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock<TestState>()
        sideEffect.executeGetStateReturnValue = PublisherType(subscribe: { subscriber in
            subscriber.onValue(Action1())
            subscriber.onValue(Action2())
            subscriber.onValue(Action3())
            return FooSubscription()
        })
        sut.sideEffectForClosure = { event in nil }

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(0, messageHandler.actionHandlerMock.actions.count)
    }

    func testSideEffectMiddlewareEventError() {
        // Given
        let sut = SideEffectMiddlewareMock<TestState>()

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock<TestState>()
        sideEffect.executeGetStateReturnValue = PublisherType(subscribe: { subscriber in
            subscriber.onValue(Action1())
            subscriber.onValue(Action2())
            subscriber.onCompleted(SomeError())
            return FooSubscription()
        })
        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingAllowEventToPropagate = true

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(3, messageHandler.actionHandlerMock.actions.count)
        XCTAssertEqual("a1", (messageHandler.actionHandlerMock.actions[0] as! Action1).name)
        XCTAssertEqual("a2", (messageHandler.actionHandlerMock.actions[1] as! Action2).name)
        XCTAssertNotNil(messageHandler.actionHandlerMock.actions[2] as? SideEffectError)
        XCTAssertNotNil((messageHandler.actionHandlerMock.actions[2] as! SideEffectError).error)
        XCTAssertEqual(event, (messageHandler.actionHandlerMock.actions[2] as! SideEffectError).originalEvent as! EventReference)
    }
}
