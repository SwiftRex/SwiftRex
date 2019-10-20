import Nimble
@testable import SwiftRex
import XCTest

class ComposedMiddlewareTests: XCTestCase {
    func testComposedMiddlewareAction() {
        let sut = ComposedMiddleware<AppAction, AppAction, TestState>()
        var newActions = [AppAction]()
        let originalActions: [AppAction] = [.foo, .bar(.alpha), .bar(.alpha), .bar(.bravo), .bar(.echo), .foo]
        var originalActionsReceived: [(middlewareName: String, action: AppAction)] = []

        ["m1", "m2"]
            .lazy
            .map { name in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.handleActionNextClosure = { [unowned middleware] action, next in
                    originalActionsReceived.append((middlewareName: name, action: action))
                    middleware.context().dispatch(action)
                    next()
                }
                return middleware
            }
            .forEach { sut.append(middleware: $0 as IsoMiddlewareMock<AppAction, TestState>) }

        sut.context = { .init(onAction: { action in
            newActions.append(action)
        }, getState: { TestState() }) }

        let expectedNewActions: [AppAction] = [
            .foo, .foo, .bar(.alpha), .bar(.alpha), .bar(.alpha), .bar(.alpha),
            .bar(.bravo), .bar(.bravo), .bar(.echo), .bar(.echo), .foo, .foo
        ]
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain should have been called")
        lastInChainWasCalledExpectation.expectedFulfillmentCount = originalActions.count

        originalActions.forEach { originalAction in
            sut.handle(action: originalAction, next: {
                lastInChainWasCalledExpectation.fulfill()
            })
        }

        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(newActions, expectedNewActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m1" }.map { $0.action }, originalActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m2" }.map { $0.action }, originalActions)
    }

    func testMiddlewareActionHandlerPropagationOnInit() {
        let middlewares = ["m1", "m2", "m3", "m4"]
            .map { _ -> IsoMiddlewareMock<AppAction, TestState> in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.handleActionNextClosure = { [unowned middleware] action, next in
                    XCTAssertNoThrow(middleware.context().getState())
                    next()
                }
                return middleware
            }

        (0..<4).forEach { index in
            expect {
                _ = middlewares[index].context()
            }.to(throwAssertion())
        }

        let composedMiddlewares = middlewares[0] <> middlewares[1] <> middlewares[2] <> middlewares[3]
        expect {
            _ = composedMiddlewares.context()
        }.to(throwAssertion())

        composedMiddlewares.context = { .init(onAction: { _ in }, getState: { TestState() }) }

        (0..<4).forEach { index in
            expect {
                _ = middlewares[index].context()
            }.toNot(throwAssertion())
        }

        expect {
            _ = composedMiddlewares.context()
        }.toNot(throwAssertion())
    }

    func testMiddlewareActionHandlerPropagationOnAppend() {
        let middlewares = ["m1", "m2", "m3", "m4"]
            .map { _ -> IsoMiddlewareMock<AppAction, TestState> in
                let middleware = IsoMiddlewareMock<AppAction, TestState>()
                middleware.handleActionNextClosure = { [unowned middleware] action, next in
                    XCTAssertNoThrow(middleware.context().getState())
                    next()
                }
                return middleware
            }

        (0..<4).forEach { index in
            expect {
                _ = middlewares[index].context()
            }.to(throwAssertion())
        }

        let composedMiddlewares = ComposedMiddleware<AppAction, AppAction, TestState>()
        expect {
            _ = composedMiddlewares.context()
        }.to(throwAssertion())

        composedMiddlewares.context = { .init(onAction: { _ in }, getState: { TestState() }) }

        expect {
            _ = composedMiddlewares.context()
        }.toNot(throwAssertion())

        middlewares.forEach { middleware in
            composedMiddlewares.append(middleware: middleware)
        }

        (0..<4).forEach { index in
            expect {
                _ = middlewares[index].context()
            }.toNot(throwAssertion())
        }
    }
}
