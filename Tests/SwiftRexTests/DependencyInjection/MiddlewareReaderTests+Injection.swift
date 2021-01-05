import SwiftRex
import XCTest

extension MiddlewareReaderTests {
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
}
