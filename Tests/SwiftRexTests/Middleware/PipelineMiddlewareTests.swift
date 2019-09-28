@testable import SwiftRex
import XCTest

class PipelineMiddlewareTests: MiddlewareTestsBase {
    func testPipelineMiddlewareEventIgnore() {
        // Given
        let shouldCallEventPipeline = expectation(description: "should call event pipeline")
        let state = TestState()
        let getState = { state }
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<TestState>(
            eventTransformer: { _ in
                let downstream = PublisherType<ActionProtocol, Never> { _ in
                    shouldCallEventPipeline.fulfill()
                    return FooSubscription()
                }
                return downstream
            },
            actionTransformer: nil,
            eventSubject: eventSubject,
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
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
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<TestState>(
            eventTransformer: { upstream in
                let downstream = PublisherType<ActionProtocol, Never> { downstreamSubscriber in
                    let subscription = upstream.subscribe(SubscriberType<(TestState, EventProtocol), Never>(
                        onValue: { upstreamState, upstreamEvent in
                            XCTAssertTrue(event === upstreamEvent as? EventReference)
                            XCTAssertEqual(state, upstreamState)
                            downstreamSubscriber.onValue(action)
                            shouldCallEventPipelineOnValue.fulfill()
                        }, onCompleted: nil))
                    shouldCallEventPipeline.fulfill()
                    return subscription
                }
                return downstream
            },
            actionTransformer: nil,
            eventSubject: eventSubject,
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
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
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<TestState>(
            eventTransformer: nil,
            actionTransformer: { _ in
                let downstream = PublisherType<ActionProtocol, Never> { _ in
                    shouldCallActionPipeline.fulfill()
                    return FooSubscription()
                }
                return downstream
            },
            eventSubject: eventSubject,
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
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
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<TestState>(
            eventTransformer: nil,
            actionTransformer: { upstream in
                let downstream = PublisherType<ActionProtocol, Never> { downstreamSubscriber in
                    let subscription = upstream.subscribe(SubscriberType<(TestState, ActionProtocol), Never>(
                        onValue: { upstreamState, upstreamAction in
                            XCTAssertTrue(originalAction === upstreamAction as? ActionReference)
                            XCTAssertEqual(state, upstreamState)
                            downstreamSubscriber.onValue(derivedAction)
                            shouldCallActionPipelineOnValue.fulfill()
                        }, onCompleted: nil))
                    shouldCallActionPipeline.fulfill()
                    return subscription
                }
                return downstream
            },
            eventSubject: eventSubject,
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
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

    let eventSubject: () -> SubjectType<(TestState, EventProtocol), Never> = {
        PassthroughSubject<(TestState, EventProtocol)>().subject
    }

    let actionSubject: () -> SubjectType<(TestState, ActionProtocol), Never> = { PassthroughSubject<(TestState, ActionProtocol)>().subject
    }
}
