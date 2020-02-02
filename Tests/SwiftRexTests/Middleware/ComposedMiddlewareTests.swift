import Nimble
@testable import SwiftRex
import XCTest

class ComposedMiddlewareTests: XCTestCase {
    func testComposedMiddlewareAction() {
        var sut = ComposedMiddleware<AppAction, AppAction, TestState>()
        var newActions = [AppAction]()
        let originalActions: [AppAction] = [.foo, .bar(.alpha), .bar(.alpha), .bar(.bravo), .bar(.echo), .foo]
        var originalActionsReceived: [(middlewareName: String, action: AppAction)] = []
        var middlewareOutput: AnyActionHandler<AppAction>?
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain should have been called")
        let expectedNewActions: [AppAction] = [
            .foo, .foo, .bar(.alpha), .bar(.alpha), .bar(.alpha), .bar(.alpha),
            .bar(.bravo), .bar(.bravo), .bar(.echo), .bar(.echo), .foo, .foo
        ]

        lastInChainWasCalledExpectation.expectedFulfillmentCount = expectedNewActions.count

        ["m1", "m2"]
            .lazy
            .map { name in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.receiveContextGetStateOutputClosure = { _, output in middlewareOutput = output }
                middleware.handleActionClosure = { action in
                    originalActionsReceived.append((middlewareName: name, action: action))
                    middlewareOutput?.dispatch(action)
                    return .do {
                        lastInChainWasCalledExpectation.fulfill()
                    }
                }
                return middleware
            }
            .forEach { sut.append(middleware: $0 as IsoMiddlewareMock<AppAction, TestState>) }

        sut.receiveContext(getState: { TestState() }, output: .init({ action in newActions.append(action) }))

        originalActions.forEach { originalAction in
            sut.handle(action: originalAction).reducerIsDone()
        }

        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(newActions, expectedNewActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m1" }.map { $0.action }, originalActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m2" }.map { $0.action }, originalActions)
    }

    func testMiddlewareActionHandlerPropagationFromComposedMiddlewareToChildrenComposedViaOperator() {
        let shouldReceiveContext = expectation(description: "context should have been received")
        shouldReceiveContext.expectedFulfillmentCount = 4
        let middlewares = ["m1", "m2", "m3", "m4"]
            .map { _ -> IsoMiddlewareMock<AppAction, TestState> in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.receiveContextGetStateOutputClosure = { _, _ in
                    shouldReceiveContext.fulfill()
                }
                middleware.handleActionClosure = { action in
                    .doNothing()
                }
                return middleware
            }

        let composedMiddlewares = middlewares[0] <> middlewares[1] <> middlewares[2] <> middlewares[3]
        composedMiddlewares.receiveContext(getState: { TestState() }, output: .init({ _ in }))

        wait(for: [shouldReceiveContext], timeout: 0.1)
    }

    func testMiddlewareActionHandlerPropagationFromComposedMiddlewareToChildrenComposedViaAppend() {
        let shouldReceiveContext = expectation(description: "context should have been received")
        shouldReceiveContext.expectedFulfillmentCount = 4
        var composedMiddlewares = ComposedMiddleware<AppAction, AppAction, TestState>()
        ["m1", "m2", "m3", "m4"]
            .map { _ -> IsoMiddlewareMock<AppAction, TestState> in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.receiveContextGetStateOutputClosure = { _, _ in
                    shouldReceiveContext.fulfill()
                }
                middleware.handleActionClosure = { action in
                    .doNothing()
                }
                return middleware
            }.forEach { middleware in
                composedMiddlewares.append(middleware: middleware)
            }

        composedMiddlewares.receiveContext(getState: { TestState() }, output: .init({ _ in }))
        wait(for: [shouldReceiveContext], timeout: 0.1)
    }
}
