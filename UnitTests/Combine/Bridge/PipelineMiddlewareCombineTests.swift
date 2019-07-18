import Combine
import CombineRex
import SwiftRex
import XCTest

class PipelineMiddlewareCombineTests: MiddlewareTestsBase {
    func testPipelineMiddlewareEventIgnore() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let state = TestState()
        let getState = { state }

        let sut = PipelineMiddleware<TestState>.combine(
            eventTransformer: { _ in
                Publishers.Empty<ActionProtocol, Never>()
                    .handleEvents(receiveSubscription: { _ in
                        shouldCallEventPipeline.fulfill()
                    })
                    .eraseToAnyPublisher()
            }
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

        let sut = PipelineMiddleware<TestState>.combine(
            eventTransformer: { upstream in
                upstream
                    .handleEvents(receiveSubscription: { _ in
                        shouldCallEventPipeline.fulfill()
                    })
                    .map { upstreamState, upstreamEvent in
                        XCTAssertTrue(event === upstreamEvent as? EventReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallEventPipelineOnValue.fulfill()
                        return action
                    }
                    .eraseToAnyPublisher()
            }
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

        let sut = PipelineMiddleware<TestState>.combine(
            actionTransformer: { _ in
                Publishers.Empty<ActionProtocol, Never>()
                    .handleEvents(receiveSubscription: { _ in
                        shouldCallActionPipeline.fulfill()
                    })
                    .eraseToAnyPublisher()
            }
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

        let sut = PipelineMiddleware<TestState>.combine(
            actionTransformer: { upstream in
                upstream
                    .handleEvents(receiveSubscription: { _ in
                        shouldCallActionPipeline.fulfill()
                    })
                    .map { upstreamState, upstreamAction in
                        XCTAssertTrue(originalAction === upstreamAction as? ActionReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallActionPipelineOnValue.fulfill()
                        return derivedAction
                    }
                    .eraseToAnyPublisher()
            }
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
