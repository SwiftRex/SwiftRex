import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTypeErasureTests: XCTestCase {
    func testAnyMiddlewareReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        middleware.eraseToAnyMiddleware().receiveContext(getState: { TestState() }, output: .init { _ in })
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(0, middleware.handleActionFromAfterReducerCallsCount)
    }

    func testAnyMiddlewareFromInitReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
            .receiveContext(getState: { TestState() }, output: .init { _ in })
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(0, middleware.handleActionFromAfterReducerCallsCount)
    }

    func testAnyMiddlewareHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionFromAfterReducerClosure = { _, _, afterReducer in
            afterReducer = .do { calledAfterReducer.fulfill() }
        }
        let erased = middleware.eraseToAnyMiddleware()
        erased.receiveContext(getState: { TestState() }, output: .init { _ in })
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.runIO(.init { _ in })
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(1, middleware.handleActionFromAfterReducerCallsCount)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testAnyMiddlewareFromInitHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionFromAfterReducerClosure = { _, _, afterReducer in
            afterReducer = .do { calledAfterReducer.fulfill() }
        }
        let erased = AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
        erased.receiveContext(getState: { TestState() }, output: .init { _ in })
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.runIO(.init { _ in })
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.receiveContextGetStateOutputCallsCount)
        XCTAssertEqual(1, middleware.handleActionFromAfterReducerCallsCount)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testAnyMiddlewareFromInitIgnoringContextHandleAction() {
        let calledBeforeReducer = expectation(description: "before reducer was called")
        let calledAfterReducer = expectation(description: "after reducer was called")
        let erased = AnyMiddleware<AppAction, AppAction, TestState> { _, _, _ in
            calledBeforeReducer.fulfill()
            return .init { _ in
                calledAfterReducer.fulfill()
            }
        }
        erased.receiveContext(getState: { TestState() }, output: .init { _ in })
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.runIO(.init { _ in })
        wait(for: [calledBeforeReducer, calledAfterReducer], timeout: 0.1, enforceOrder: true)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testAnyMiddlewareContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let action = AppAction.bar(.charlie)
        let receivedAction = expectation(description: "action should have been received")

        let typeErased = middleware.eraseToAnyMiddleware()
        typeErased.receiveContext(
            getState: { state },
            output: .init { dispatchedAction in
                XCTAssertEqual(action, dispatchedAction.action)
                XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
                XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
                XCTAssertEqual(666, dispatchedAction.dispatcher.line)
                XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
                receivedAction.fulfill()
            }
        )
        middleware.receiveContextGetStateOutputReceivedArguments?.output.dispatch(
            action,
            from: .init(file: "file_1", function: "function_1", line: 666, info: "info_1")
        )

        XCTAssertEqual(state.value, middleware.receiveContextGetStateOutputReceivedArguments?.getState().value)
        XCTAssertFalse(typeErased.isIdentity)
        XCTAssertNil(typeErased.isComposed)
        wait(for: [receivedAction], timeout: 0.1)
    }

    func testAnyMiddlewareFromInitContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let action = AppAction.bar(.charlie)
        let receivedAction = expectation(description: "action should have been received")

        let typeErased = AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
        typeErased.receiveContext(
            getState: { state },
            output: .init { dispatchedAction in
                XCTAssertEqual(action, dispatchedAction.action)
                XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
                XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
                XCTAssertEqual(666, dispatchedAction.dispatcher.line)
                XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
                receivedAction.fulfill()
            }
        )
        middleware.receiveContextGetStateOutputReceivedArguments?.output.dispatch(
            action,
            from: .init(file: "file_1", function: "function_1", line: 666, info: "info_1")
        )

        XCTAssertEqual(state.value, middleware.receiveContextGetStateOutputReceivedArguments?.getState().value)
        XCTAssertFalse(typeErased.isIdentity)
        XCTAssertNil(typeErased.isComposed)
        wait(for: [receivedAction], timeout: 0.1)
    }

    func testEraseIdentityThroughExtensionKeepsThatInformation() {
        let identity = IdentityMiddleware<String, String, String>()
        let erased = identity.eraseToAnyMiddleware()
        XCTAssertTrue(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testEraseIdentityThroughExtensionMultipleTimesKeepsThatInformation() {
        let identity = IdentityMiddleware<String, String, String>()
        let erased = identity.eraseToAnyMiddleware().eraseToAnyMiddleware().eraseToAnyMiddleware()
        XCTAssertTrue(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testEraseIdentityThroughInitKeepsThatInformation() {
        let identity = IdentityMiddleware<String, String, String>()
        let erased = AnyMiddleware(identity)
        XCTAssertTrue(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testEraseIdentityThroughInitMultipleTimesKeepsThatInformation() {
        let identity = IdentityMiddleware<String, String, String>()
        let erased = AnyMiddleware(AnyMiddleware(AnyMiddleware(identity)))
        XCTAssertTrue(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testEraseComposedMiddlewareThroughExtensionKeepsThatInformation() {
        var composed = ComposedMiddleware<String, String, String>()
        let someMiddleware = MiddlewareMock<String, String, String>()
        composed.append(middleware: someMiddleware)
        let erased = composed.eraseToAnyMiddleware()
        XCTAssertFalse(erased.isIdentity)
        XCTAssertEqual(erased.isComposed?.middlewares.count, 1)
    }

    func testEraseComposedMiddlewareThroughExtensionMultipleTimesKeepsThatInformation() {
        var composed = ComposedMiddleware<String, String, String>()
        let someMiddleware = MiddlewareMock<String, String, String>()
        composed.append(middleware: someMiddleware)
        let erased = composed.eraseToAnyMiddleware().eraseToAnyMiddleware().eraseToAnyMiddleware()
        XCTAssertFalse(erased.isIdentity)
        XCTAssertEqual(erased.isComposed?.middlewares.count, 1)
    }

    func testEraseComposedMiddlewareThroughInitKeepsThatInformation() {
        var composed = ComposedMiddleware<String, String, String>()
        let someMiddleware = MiddlewareMock<String, String, String>()
        composed.append(middleware: someMiddleware)
        let erased = AnyMiddleware(composed)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertEqual(erased.isComposed?.middlewares.count, 1)
    }

    func testEraseComposedMiddlewareThroughInitMultipleTimesKeepsThatInformation() {
        var composed = ComposedMiddleware<String, String, String>()
        let someMiddleware = MiddlewareMock<String, String, String>()
        composed.append(middleware: someMiddleware)
        let erased = AnyMiddleware(AnyMiddleware(AnyMiddleware(composed)))
        XCTAssertFalse(erased.isIdentity)
        XCTAssertEqual(erased.isComposed?.middlewares.count, 1)
    }
}
