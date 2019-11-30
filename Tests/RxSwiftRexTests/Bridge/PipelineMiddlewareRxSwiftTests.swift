import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class PipelineMiddlewareRxSwiftTests: MiddlewareTestsBase {
    func testPipelineMiddlewareEventIgnore() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let state = TestState()
        let getState = { state }

        let sut = PipelineMiddleware<TestState>.rx(
            eventTransformer: { _ in
                Observable<ActionProtocol>
                    .empty()
                    .do(onSubscribed: {
                        shouldCallEventPipeline.fulfill()
                    })
            }
        )

        let middlewareContext = MiddlewareContextMock()
        sut.context = { middlewareContext.value }
        let event = EventReference()
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallEventPipeline, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(0, middlewareContext.actionHandlerMock.actions.count)
    }

    func testPipelineMiddlewareEventTransformPipeline() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let shouldCallEventPipelineOnValue = expectation(description: "should call event pipeline on value")
        let state = TestState()
        let getState = { state }
        let event = EventReference()
        let action = ActionReference()

        let sut = PipelineMiddleware<TestState>.rx(
            eventTransformer: { upstream in
                upstream
                    .do(onSubscribed: {
                        shouldCallEventPipeline.fulfill()
                    })
                    .map { upstreamState, upstreamEvent in
                        XCTAssertTrue(event === upstreamEvent as? EventReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallEventPipelineOnValue.fulfill()
                        return action
                    }
            }
        )

        let middlewareContext = MiddlewareContextMock()
        sut.context = { middlewareContext.value }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastEventInChain(event, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(event: event, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallEventPipeline, shouldCallEventPipelineOnValue, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, middlewareContext.actionHandlerMock.actions.count)
        XCTAssertTrue(action === middlewareContext.actionHandlerMock.actions.first as? ActionReference)
    }

    func testPipelineMiddlewareActionIgnore() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let state = TestState()
        let getState = { state }
        let action = ActionReference()

        let sut = PipelineMiddleware<TestState>.rx(
            actionTransformer: { _ in
                Observable<ActionProtocol>
                    .empty()
                    .do(onSubscribed: {
                        shouldCallActionPipeline.fulfill()
                    })
            }
        )

        let middlewareContext = MiddlewareContextMock()
        sut.context = { middlewareContext.value }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(action, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: action, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallActionPipeline, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(0, middlewareContext.actionHandlerMock.actions.count)
    }

    func testPipelineMiddlewareActionTransformPipeline() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let shouldCallActionPipelineOnValue = expectation(description: "should call action pipeline on value")
        let state = TestState()
        let getState = { state }
        let originalAction = ActionReference()
        let derivedAction = ActionReference()

        let sut = PipelineMiddleware<TestState>.rx(
            actionTransformer: { upstream in
                upstream
                    .do(onSubscribed: {
                        shouldCallActionPipeline.fulfill()
                    })
                    .map { upstreamState, upstreamAction in
                        XCTAssertTrue(originalAction === upstreamAction as? ActionReference)
                        XCTAssertEqual(state, upstreamState)
                        shouldCallActionPipelineOnValue.fulfill()
                        return derivedAction
                    }
            }
        )

        let middlewareContext = MiddlewareContextMock()
        sut.context = { middlewareContext.value }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")
        let lastInChain = lastActionInChain(originalAction, state: state, expectation: lastInChainWasCalledExpectation)

        // Then
        sut.handle(action: originalAction, getState: getState, next: lastInChain)

        // Expect
        wait(for: [shouldCallActionPipeline, shouldCallActionPipelineOnValue, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(1, middlewareContext.actionHandlerMock.actions.count)
        XCTAssertTrue(derivedAction === middlewareContext.actionHandlerMock.actions.first as? ActionReference)
        XCTAssertFalse(originalAction === middlewareContext.actionHandlerMock.actions.first as? ActionReference)
    }
}
