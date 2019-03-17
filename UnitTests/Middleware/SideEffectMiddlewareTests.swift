@testable import SwiftRex
import XCTest

class SideEffectMiddlewareTests: MiddlewareTestsBase {
    func testSideEffectMiddlewareAction() {
        // Given
        let sut = SideEffectMiddlewareMock()

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

    func testSideEffectMiddlewareEvent() {
        // Given
        let sut = SideEffectMiddlewareMock()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock()
        sideEffect.executeGetStateReturnValue = observable(of: Action1(), Action2(), Action3())
        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingSubscriptionOwner = SubscriptionOwner.new()
        sut.underlyingAllowEventToPropagate = true
        var actionsCalled: [ActionProtocol] = []
        actionHandler.triggerClosure = { action in actionsCalled.append(action) }

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(3, actionHandler.triggerCallsCount)
        XCTAssertEqual("a1", (actionsCalled[0] as! Action1).name)
        XCTAssertEqual("a2", (actionsCalled[1] as! Action2).name)
        XCTAssertEqual("a3", (actionsCalled[2] as! Action3).name)
    }

    func testSideEffectMiddlewareEventNoPropagation() {
        // Given
        let sut = SideEffectMiddlewareMock()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let sideEffect = SideEffectProducerMock()
        sideEffect.executeGetStateReturnValue = observable(of: Action1(), Action2(), Action3())
        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingSubscriptionOwner = SubscriptionOwner.new()
        sut.underlyingAllowEventToPropagate = false
        var actionsCalled: [ActionProtocol] = []
        actionHandler.triggerClosure = { action in actionsCalled.append(action) }

        // Then
        sut.handle(event: event, getState: getState, next: { _, _ in XCTFail("It should be propagating") })

        // Expect
        XCTAssertEqual(3, actionHandler.triggerCallsCount)
        XCTAssertEqual("a1", (actionsCalled[0] as! Action1).name)
        XCTAssertEqual("a2", (actionsCalled[1] as! Action2).name)
        XCTAssertEqual("a3", (actionsCalled[2] as! Action3).name)
    }

    func testSideEffectMiddlewareUnknownEvent() {
        // Given
        let sut = SideEffectMiddlewareMock()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock()
        sideEffect.executeGetStateReturnValue = observable(of: Action1(), Action2(), Action3())
        sut.sideEffectForClosure = { event in nil }

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(0, actionHandler.triggerCallsCount)
    }

    func testSideEffectMiddlewareEventError() {
        // Given
        let sut = SideEffectMiddlewareMock()

        let actionHandler = ActionHandlerMock()
        sut.actionHandler = actionHandler
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)
        let sideEffect = SideEffectProducerMock()
        sideEffect.executeGetStateReturnValue =
            observable(of: Action1(), Action2())
                .concat(observable(of: ActionProtocol.self, error: SomeError()))
        sut.sideEffectForReturnValue = AnySideEffectProducer(sideEffect)
        sut.underlyingSubscriptionOwner = SubscriptionOwner.new()
        sut.underlyingAllowEventToPropagate = true
        var actionsCalled: [ActionProtocol] = []
        actionHandler.triggerClosure = { action in actionsCalled.append(action) }

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(3, actionHandler.triggerCallsCount)
        XCTAssertEqual("a1", (actionsCalled[0] as! Action1).name)
        XCTAssertEqual("a2", (actionsCalled[1] as! Action2).name)
        XCTAssertNotNil(actionsCalled[2] as? SideEffectError)
        XCTAssertNotNil((actionsCalled[2] as! SideEffectError).error)
        XCTAssertEqual(event, (actionsCalled[2] as! SideEffectError).originalEvent as! EventReference)
    }
}
