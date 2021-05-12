import SwiftRex
import XCTest

extension MiddlewareReaderTests {
    func testMiddlewareReaderPure() {
        // Given
        let middleware = MiddlewareMock<String, String, String>()
        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.pure(middleware)

        // When
        let resultMiddleware = reader.inject("Some environment")

        // Then
        XCTAssert(middleware === resultMiddleware)
    }
}
