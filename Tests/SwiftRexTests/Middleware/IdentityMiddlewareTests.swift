@testable import SwiftRex
import XCTest

class IdentityMiddlewareTests: XCTestCase {
    func testIdentityMiddlewareAction() {
        // Given
        let sut = IdentityMiddleware<AppAction, AppAction, TestState>()

        let middlewareContext = MiddlewareContextMock<AppAction, TestState>()
        sut.context = { middlewareContext.value }
        let action = AppAction.bar(.delta)
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain was called")

        // Then
        sut.handle(action: action) {
            lastInChainWasCalledExpectation.fulfill()
        }

        // Expect
        wait(for: [lastInChainWasCalledExpectation], timeout: 3)
        XCTAssertEqual(0, middlewareContext.onActionCount)
        XCTAssertEqual(0, middlewareContext.getStateCount)
    }
}
