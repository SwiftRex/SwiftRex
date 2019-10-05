import Foundation
import Nimble
@testable import SwiftRex
import XCTest

class TypeErasureTests: XCTestCase {
    func testMiddlewareBaseInitThrows() {
        expect { _ = _AnyMiddlewareBase<AppAction, TestState>() }.to(throwAssertion())
    }

    func testMiddlewareBaseHandleActionThrows() {
        let sut = MiddlewareAbstract<AppAction, TestState>()
        expect {
            sut.handle(action: AppAction.foo, next: { })
        }.to(throwAssertion())
    }

    func testMiddlewareBaseContextGetThrows() {
        let sut = MiddlewareAbstract<AppAction, TestState>()
        expect {
            _ = sut.context
        }.to(throwAssertion())
    }

    func testMiddlewareBaseContextSetThrows() {
        let sut = MiddlewareAbstract<AppAction, TestState>()
        let context = MiddlewareContext<AppAction, TestState>(onAction: { _ in }, getState: { TestState() })
        expect {
            sut.context = { context }
        }.to(throwAssertion())
    }

    func testAnyMiddlewareInit() {
        let middleware = MiddlewareMock<AppAction, TestState>()
        expect {
            _ = AnyMiddleware(middleware)
        }.toNot(throwError())
    }

    func testAnyMiddlewareHandleAction() {
        let middleware = MiddlewareMock<AppAction, TestState>()
        let sut = AnyMiddleware(middleware)
        sut.handle(action: .foo, next: { })
        XCTAssertTrue(middleware.handleActionNextCalled)
    }

    func testAnyMiddlewareContextGetsFromWrapped() {
        let middleware = MiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let context = MiddlewareContext<AppAction, TestState>(onAction: { _ in }, getState: { state })

        middleware.context = { context }
        let typeErased = AnyMiddleware(middleware)
        let typeErasedContext = typeErased.context()

        XCTAssertEqual(state.value, typeErasedContext.getState().value)
    }

    func testAnyMiddlewareContextSetsIntoWrapped() {
        let middleware = MiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let context = MiddlewareContext<AppAction, TestState>(onAction: { _ in }, getState: { state })

        let typeErased = AnyMiddleware(middleware)
        typeErased.context = { context }
        let wrappedMiddlewareContext = middleware.context()

        XCTAssertEqual(state.value, wrappedMiddlewareContext.getState().value)
    }
}

private class MiddlewareAbstract<A, S>: _AnyMiddlewareBase<A, S> {
}
