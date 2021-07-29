@testable import SwiftRex
import XCTest

extension MiddlewareReaderTests {
    func testMiddlewareReaderIdentityMiddlewareAction() {
        // Given
        let reader = MiddlewareReader<String, MiddlewareMock<AppAction, AppAction, TestState>>.identity
        let sut = reader.inject("some")
        var getStateCount = 0
        var dispatchActionCount = 0

        let action = AppAction.bar(.delta)

        // Then
        sut.handle(
            action: action,
            from: .here(),
            state: {
                getStateCount += 1
                return TestState()
            }
        ).runIO(.init({ _ in dispatchActionCount += 1 }))

        // Expect
        let mirror = Mirror(reflecting: sut)
        XCTAssertEqual("Mirror for IdentityMiddleware<AppAction, AppAction, TestState>", mirror.description)
        XCTAssertEqual(0, dispatchActionCount)
        XCTAssertEqual(0, getStateCount)
    }

    func testMiddlewareReaderMonoidIdentityMiddlewareAction() {
        // Given
        let state = TestState()
        let reader = MiddlewareReader<String, MonoidMiddleware<AppAction, AppAction, TestState>>.identity
        let sut = reader.inject("some")
        var getStateCount = 0
        var dispatchActionCount = 0

        let action = AppAction.bar(.delta)

        // Then
        sut.mock.handleActionFromStateClosure = { receivedAction, _, receivedState in
            XCTAssertEqual(receivedAction, action)
            XCTAssertEqual(receivedState(), state)
            return .pure()
        }
        sut.handle(
            action: action,
            from: .here(),
            state: {
                getStateCount += 1
                return state
            }
        ).runIO(.init { _ in dispatchActionCount += 1 })

        // Expect
        let mirror = Mirror(reflecting: sut)
        XCTAssertEqual("Mirror for MonoidMiddleware<AppAction, AppAction, TestState>", mirror.description)
        XCTAssertEqual(0, dispatchActionCount)
        XCTAssertEqual(1, getStateCount)
    }
}
