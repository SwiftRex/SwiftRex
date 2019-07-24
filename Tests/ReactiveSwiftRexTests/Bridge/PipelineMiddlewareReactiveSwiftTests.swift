import ReactiveSwift
import ReactiveSwiftRex
import SwiftRex
import XCTest

class PipelineMiddlewareReactiveSwiftTests: MiddlewareTestsBase {
    func testPipelineMiddlewareEventIgnore() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let state = TestState()
        let getState = { state }
        let token = Lifetime.Token()

        let sut = PipelineMiddleware<TestState>.reactive(
            eventTransformer: { _ in
                SignalProducer<ActionProtocol, Never>
                    .empty
                    .on(starting: { shouldCallEventPipeline.fulfill() })
            },
            token: token
        )

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallEventPipeline, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(0, messageHandler.actionHandlerMock.actions.count)
    }

    func testPipelineMiddlewareEventTransformPipeline() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let shouldCallEventPipelineOnValue = expectation(description: "should call event pipeline on value")
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let action = ActionReference()
        let token = Lifetime.Token()

        let sut = PipelineMiddleware<TestState>.reactive(
            eventTransformer: { upstream in
                upstream
                    .on(starting: {
                        shouldCallEventPipeline.fulfill()
                    })
                    .map { upstreamState, upstreamEvent in
                        XCTAssertTrue(event === upstreamEvent as? EventReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallEventPipelineOnValue.fulfill()
                        return action
                    }
            },
            token: token
        )

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallEventPipeline, shouldCallEventPipelineOnValue, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, messageHandler.actionHandlerMock.actions.count)
        XCTAssertTrue(action === messageHandler.actionHandlerMock.actions.first as? ActionReference)
    }

    func testPipelineMiddlewareActionIgnore() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let state = TestState()
        let getState = { state }
        let action = ActionReference()
        let token = Lifetime.Token()

        let sut = PipelineMiddleware<TestState>.reactive(
            actionTransformer: { _ in
                SignalProducer<ActionProtocol, Never>
                    .empty
                    .on(starting: { shouldCallActionPipeline.fulfill() })
            },
            token: token
        )

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallActionPipeline, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(0, messageHandler.actionHandlerMock.actions.count)
    }

    func testPipelineMiddlewareActionTransformPipeline() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let shouldCallActionPipelineOnValue = expectation(description: "should call action pipeline on value")
        let state = TestState()
        let getState = { state }
        let originalAction = ActionReference()
        let derivedAction = ActionReference()
        let token = Lifetime.Token()

        let sut = PipelineMiddleware<TestState>.reactive(
            actionTransformer: { upstream in
                upstream
                    .on(starting: { shouldCallActionPipeline.fulfill() })
                    .map { upstreamState, upstreamAction in
                        XCTAssertTrue(originalAction === upstreamAction as? ActionReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallActionPipelineOnValue.fulfill()
                        return derivedAction
                    }
            },
            token: token
        )

        let messageHandler = MessageHandlerMock()
        sut.handlers = messageHandler.value
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(originalAction, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: originalAction, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallActionPipeline, shouldCallActionPipelineOnValue, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, messageHandler.actionHandlerMock.actions.count)
        XCTAssertTrue(derivedAction === messageHandler.actionHandlerMock.actions.first as? ActionReference)
        XCTAssertFalse(originalAction === messageHandler.actionHandlerMock.actions.first as? ActionReference)
    }
}
