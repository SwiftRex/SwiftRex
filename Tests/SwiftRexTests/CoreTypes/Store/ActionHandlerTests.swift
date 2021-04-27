import Foundation
@testable import SwiftRex
import XCTest

class ActionHandlerTests: XCTestCase {
    func testDefaultSource() {
        let handleTwice = expectation(description: "should have handled two actions")
        handleTwice.expectedFulfillmentCount = 2
        let sut = AnyActionHandler<String> { dispatchedAction in
            switch dispatchedAction.action {
            case "1":
                XCTAssertEqual(dispatchedAction.dispatcher.line, 24)
                XCTAssertNil(dispatchedAction.dispatcher.info)
            case "2":
                XCTAssertEqual(dispatchedAction.dispatcher.line, 26)
                XCTAssertEqual(dispatchedAction.dispatcher.info, "second")
            default: XCTFail("Too many actions")
            }
            XCTAssert(dispatchedAction.dispatcher.file.hasSuffix("/ActionHandlerTests.swift"))
            XCTAssertEqual(dispatchedAction.dispatcher.function, "testDefaultSource()")
            handleTwice.fulfill()
        }

        sut.dispatch("1")
        _ = "skip line"
        sut.dispatch("2", info: "second")

        wait(for: [handleTwice], timeout: 0.1)
    }
}
