@testable import SwiftRex
import XCTest

class MiddlewareReaderTests: XCTestCase {
    func testMiddlewareReaderCreatesMiddlewareCorrectly() {
        // Given
        let middleware = MiddlewareMock<String, String, String>()
        let expectsToCallInjection = expectation(description: "Should have called injection")

        let reader = MiddlewareReader { (environment: String) -> MiddlewareMock<String, String, String> in
            XCTAssertEqual("Some environment", environment)
            expectsToCallInjection.fulfill()
            return middleware
        }

        // When
        let resultMiddleware = reader.inject("Some environment")

        // Then
        wait(for: [expectsToCallInjection], timeout: 0)
        XCTAssert(middleware === resultMiddleware)
    }

    func testMiddlewareReaderPure() {
        // Given
        let middleware = MiddlewareMock<String, String, String>()
        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.pure(middleware)

        // When
        let resultMiddleware = reader.inject("Some environment")

        // Then
        XCTAssert(middleware === resultMiddleware)
    }

    func testMiddlewareReaderIdentityMiddlewareAction() {
        // Given
        let reader = MiddlewareReader<String, MiddlewareMock<AppAction, AppAction, TestState>>.identity
        let sut = reader.inject("some")
        var getStateCount = 0
        var dispatchActionCount = 0

        sut.receiveContext(
            getState: {
                getStateCount += 1
                return TestState()
            },
            output: .init { _, _ in
                dispatchActionCount += 1
            })
        let action = AppAction.bar(.delta)

        // Then
        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: action, from: .here(), afterReducer: &afterReducer)

        // Expect
        let mirror = Mirror(reflecting: sut)
        XCTAssertEqual("Mirror for IdentityMiddleware<AppAction, AppAction, TestState>", mirror.description)
        XCTAssertEqual(0, dispatchActionCount)
        XCTAssertEqual(0, getStateCount)
    }

    func testMiddlewareReaderMonoidIdentityMiddlewareAction() {
        // Given
        let reader = MiddlewareReader<String, MonoidMiddleware<AppAction, AppAction, TestState>>.identity
        let sut = reader.inject("some")
        var getStateCount = 0
        var dispatchActionCount = 0

        sut.receiveContext(
            getState: {
                getStateCount += 1
                return TestState()
            },
            output: .init { _, _ in
                dispatchActionCount += 1
            })
        let action = AppAction.bar(.delta)

        // Then
        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: action, from: .here(), afterReducer: &afterReducer)

        // Expect
        let mirror = Mirror(reflecting: sut)
        XCTAssertEqual("Mirror for MonoidMiddleware<AppAction, AppAction, TestState>", mirror.description)
        XCTAssertEqual(0, dispatchActionCount)
        XCTAssertEqual(0, getStateCount)
    }
}

struct MonoidMiddleware<InputActionType, OutputActionType, StateType>: Middleware, Monoid {
    func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
    }

    func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
    }

    let string: String

    static var identity: MonoidMiddleware {
        .init(string: "")
    }

    static func <> (lhs: MonoidMiddleware, rhs: MonoidMiddleware) -> MonoidMiddleware {
        .init(string: lhs.string + rhs.string)
    }
}
