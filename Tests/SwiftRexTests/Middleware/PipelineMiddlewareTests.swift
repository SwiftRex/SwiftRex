@testable import SwiftRex
import XCTest

class PipelineMiddlewareTests: XCTestCase {
    func testPipelineMiddlewareIgnoreAction() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let state = TestState()
        let action = AppAction.bar(.charlie)
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<AppAction, AppAction, TestState>(
            actionTransformer: { _ in
                let downstream = PublisherType<AppAction, Never> { _ in
                    shouldCallActionPipeline.fulfill()
                    return FooSubscription()
                }
                return downstream
            },
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
        )

        let middlewareContext = MiddlewareContextMock<AppAction, TestState>()
        middlewareContext.state = state
        sut.context = { middlewareContext.value }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")

        // Then
        sut.handle(action: action, next: {
            lastInChainWasCalledExpectation.fulfill()
        })

        // Expect
        wait(for: [shouldCallActionPipeline, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(0, middlewareContext.onActionCount)
    }

    func testPipelineMiddlewareDispatchNewActions() {
        // Given
        let shouldCallActionPipeline = expectation(description: "should call action pipeline")
        let shouldCallActionPipelineOnValue = expectation(description: "should call action pipeline on value")
        let state = TestState()
        let originalAction = AppAction.bar(.charlie)
        let derivedActions = [AppAction.bar(.charlie), .foo]
        let disposables = FooSubscriptionCollection()

        let sut = PipelineMiddleware<AppAction, AppAction, TestState>(
            actionTransformer: { upstream in
                let downstream = PublisherType<AppAction, Never> { downstreamSubscriber in
                    let subscription = upstream.subscribe(SubscriberType<(AppAction, TestState), Never>(
                        onValue: { upstreamAction, upstreamState in
                            XCTAssertEqual(originalAction, upstreamAction)
                            XCTAssertEqual(state, upstreamState)
                            derivedActions.enumerated().forEach { index, derivedAction in
                                DispatchQueue.global().asyncAfter(deadline: .now() + 0.4 * Double(index)) {
                                    downstreamSubscriber.onValue(derivedAction)
                                    if index == 1 {
                                        shouldCallActionPipelineOnValue.fulfill()
                                    }
                                }
                            }
                        }, onCompleted: nil))
                    shouldCallActionPipeline.fulfill()
                    return subscription
                }
                return downstream
            },
            actionSubject: actionSubject,
            subscriptionCollection: { disposables }
        )

        let middlewareContext = MiddlewareContextMock<AppAction, TestState>()
        middlewareContext.state = state
        sut.context = { middlewareContext.value }
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")

        // Then
        sut.handle(action: originalAction, next: {
            lastInChainWasCalledExpectation.fulfill()
        })

        // Expect
        wait(for: [shouldCallActionPipeline, shouldCallActionPipelineOnValue, lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(2, middlewareContext.onActionCount)
        XCTAssertEqual(derivedActions, middlewareContext.onActionParameters)
    }

    let actionSubject: () -> SubjectType<(AppAction, TestState), Never> = {
        PassthroughSubject<(AppAction, TestState)>().subject
    }
}
