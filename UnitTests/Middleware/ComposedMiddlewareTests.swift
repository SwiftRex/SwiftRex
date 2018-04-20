@testable import SwiftRex
import XCTest

class ComposedMiddlewareTests: MiddlewareTestsBase {
    func testComposedMiddlewareAction() {
        // Given
        let sut = ComposedMiddleware<TestState>()
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

    func testComposedMiddlewareEvent() {
        // Given
        let sut = ComposedMiddleware<TestState>()
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

    func testComposedMiddlewareOrderAction() {
        // Given
        let sut = ComposedMiddleware<TestState>()
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

    func testComposedMiddlewareOrderEvent() {
        // Given
        let sut = ComposedMiddleware<TestState>()
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

    func testMiddlewareActionHandlerPropagationOnInit() {
        let middlewares = ["m1", "m2", "m3", "m4"]
            .map(RotationMiddleware.init)
        (0..<4).forEach { XCTAssertNil(middlewares[$0].actionHandler) }

        let composedMiddlewares = middlewares[0] >>> middlewares[1] >>> middlewares[2] >>> middlewares[3]
        XCTAssertNil(composedMiddlewares.actionHandler)

        let store = TestStore(initialState: TestState(),
                              reducer: createReducerMock().0,
                              middleware: composedMiddlewares)
        (0..<4).forEach { XCTAssert(middlewares[$0].actionHandler === store) }
    }

    func testMiddlewareActionHandlerPropagationOnAppend() {
        let container: ComposedMiddleware<TestState> = .init()
        let store = TestStore(initialState: TestState(), reducer: createReducerMock().0, middleware: container)

        let middlewares = ["m1", "m2", "m3", "m4"]
            .map(RotationMiddleware.init)

        (0..<4).forEach { XCTAssertNil(middlewares[$0].actionHandler) }
        (0..<4).map { middlewares[$0] }.forEach(container.append)
        (0..<4).forEach { XCTAssert(middlewares[$0].actionHandler === store) }
    }
}
