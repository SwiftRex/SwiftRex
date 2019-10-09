import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareContextTests: XCTestCase {
    func testDispatch() {
        let shouldCallOnAction = expectation(description: "on action should have been called")
        let sut = MiddlewareContext<AppAction, TestState>(
            onAction: { action in
                XCTAssertEqual(action, .foo)
                shouldCallOnAction.fulfill()
            },
            getState: { fatalError("get state was not supposed to be called in this test") })
        sut.dispatch(.foo)
        wait(for: [shouldCallOnAction], timeout: 0.1)
    }

    func testGetState() {
        let shouldCallGetState = expectation(description: "get state should have been called")
        let currentState = TestState()
        let sut = MiddlewareContext<AppAction, TestState>(
            onAction: { _ in XCTFail("on action was not supposed to be called in this test") },
            getState: {
                shouldCallGetState.fulfill()
                return currentState
            })

        XCTAssertEqual(currentState.value, sut.getState().value)
        wait(for: [shouldCallGetState], timeout: 0.1)
    }
}
