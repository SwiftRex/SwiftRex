import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTypeErasureTests: XCTestCase {
    func testAnyMiddlewareReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        middleware.handleActionFromStateReturnValue = .pure()
        middleware.eraseToAnyMiddleware()
            .handle(action: .foo, from: .here(), state: { TestState() })
            .run(.init { _ in })
        XCTAssertEqual(1, middleware.handleActionFromStateCallsCount)
    }

    func testAnyMiddlewareFromInitReceivedContext() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        middleware.handleActionFromStateReturnValue = .pure()
        AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
            .handle(action: .foo, from: .here(), state: { TestState() })
            .run(.init { _ in })
        XCTAssertEqual(1, middleware.handleActionFromStateCallsCount)
    }

    func testAnyMiddlewareHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionFromStateClosure = { _, _, _ in
            IO { _ in calledAfterReducer.fulfill() }
        }
        let erased = middleware.eraseToAnyMiddleware()
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.run(.init { _ in })
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.handleActionFromStateCallsCount)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testAnyMiddlewareFromInitHandleAction() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let calledAfterReducer = expectation(description: "after reducer was called")
        middleware.handleActionFromStateClosure = { _, _, _ in
            IO { _ in calledAfterReducer.fulfill() }
        }
        let erased = AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.run(.init { _ in })
        wait(for: [calledAfterReducer], timeout: 0.1)
        XCTAssertEqual(1, middleware.handleActionFromStateCallsCount)
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
        let io = erased.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
        io.run(.init { _ in })
        wait(for: [calledBeforeReducer, calledAfterReducer], timeout: 0.1, enforceOrder: true)
        XCTAssertFalse(erased.isIdentity)
        XCTAssertNil(erased.isComposed)
    }

    func testAnyMiddlewareContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let action = AppAction.bar(.charlie)
        let state = TestState(value: UUID(), name: "")
        let receivedAction = expectation(description: "action should have been received")
        middleware.handleActionFromStateReturnValue = IO { output in
            output.dispatch(.init(action, dispatcher: .init(file: "file_1", function: "function_1", line: 666, info: "info_1")))
        }

        let typeErased = middleware.eraseToAnyMiddleware()
        typeErased.handle(
            action: .foo,
            from: .here(),
            state: { state }
        ).run(.init { dispatchedAction in
            XCTAssertEqual(action, dispatchedAction.action)
            XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
            XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
            XCTAssertEqual(666, dispatchedAction.dispatcher.line)
            XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
            receivedAction.fulfill()
        })

        XCTAssertEqual(state.value, middleware.handleActionFromStateReceivedArguments?.state().value)
        XCTAssertFalse(typeErased.isIdentity)
        XCTAssertNil(typeErased.isComposed)
        wait(for: [receivedAction], timeout: 0.1)
    }

    func testAnyMiddlewareFromInitContextGetsFromWrapped() {
        let middleware = IsoMiddlewareMock<AppAction, TestState>()
        let state = TestState(value: UUID(), name: "")
        let action = AppAction.bar(.charlie)
        let receivedAction = expectation(description: "action should have been received")
        middleware.handleActionFromStateReturnValue = IO { output in
            output.dispatch(.init(action, dispatcher: .init(file: "file_1", function: "function_1", line: 666, info: "info_1")))
        }

        let typeErased = AnyMiddleware(receiveContext: middleware.receiveContext, handle: middleware.handle)
        typeErased.handle(
            action: .foo,
            from: .here(),
            state: { state }
        ).run(.init { dispatchedAction in
                XCTAssertEqual(action, dispatchedAction.action)
                XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
                XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
                XCTAssertEqual(666, dispatchedAction.dispatcher.line)
                XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
                receivedAction.fulfill()
        })

        XCTAssertEqual(state.value, middleware.handleActionFromStateReceivedArguments?.state().value)
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
