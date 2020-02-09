import Foundation
@testable import SwiftRex
import XCTest

class ActionHandlerTests: XCTestCase {
    func testDefaultSource() {
        let handleTwice = expectation(description: "should have handled two actions")
        handleTwice.expectedFulfillmentCount = 2
        let sut = AnyActionHandler<String> { action, dispatcher in
            switch action {
            case "1":
                XCTAssertEqual(dispatcher.line, 24)
                XCTAssertNil(dispatcher.info)
            case "2":
                XCTAssertEqual(dispatcher.line, 26)
                XCTAssertEqual(dispatcher.info, "second")
            default: XCTFail("Too many actions")
            }
            XCTAssert(dispatcher.file.hasSuffix("/ActionHandlerTests.swift"))
            XCTAssertEqual(dispatcher.function, "testDefaultSource()")
            handleTwice.fulfill()
        }

        sut.dispatch("1")
        _ = "skip line"
        sut.dispatch("2", info: "second")

        wait(for: [handleTwice], timeout: 0.1)
    }
}
