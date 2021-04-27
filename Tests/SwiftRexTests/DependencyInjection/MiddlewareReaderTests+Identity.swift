import SwiftRex
import XCTest

extension MiddlewareReaderTests {
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
            output: .init { _ in
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
            output: .init { _ in
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
