@testable import SwiftRex
import XCTest

class IdentityMiddlewareTests: XCTestCase {
    func testIdentityMiddlewareAction() {
        // Given
        let sut = IdentityMiddleware<AppAction, AppAction, TestState>()
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
        XCTAssertEqual(0, dispatchActionCount)
        XCTAssertEqual(0, getStateCount)
    }
}
