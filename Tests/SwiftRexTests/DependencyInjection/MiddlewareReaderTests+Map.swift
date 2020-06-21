import SwiftRex
import XCTest

extension MiddlewareReaderTests {
    func testMiddlewareReaderMap() {
        let original = MiddlewareMock<String, String, String>()
        let mapped = MonoidMiddleware<String, String, String>(string: "a")
        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.init { dependency in
            XCTAssertEqual("some dependency", dependency)
            return original
        }
        let mappedReader = reader.mapMiddleware { middleware -> MonoidMiddleware<String, String, String> in
            XCTAssert(middleware === original)
            return mapped
        }

        let resultingMiddleware = mappedReader.inject("some dependency")
        XCTAssertEqual(resultingMiddleware.string, "a")
    }

    func testMiddlewareReaderContramap() {
        let middleware = MiddlewareMock<String, String, String>()
        let originalDependency = 42
        let mappedDepedency = "42"
        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.init { dependency in
            XCTAssertEqual(mappedDepedency, dependency)
            return middleware
        }
        let mappedReader = reader.contramapDependecies { (int: Int) -> String in
            XCTAssertEqual(originalDependency, int)
            return String(int)
        }

        let resultingMiddleware = mappedReader.inject(originalDependency)
        XCTAssert(resultingMiddleware === middleware)
    }

    func testMiddlewareReaderDimap() {
        let originalMiddleware = MiddlewareMock<String, String, String>()
        let mappedMiddlware = MonoidMiddleware<String, String, String>(string: "a")
        let originalDependency = 42
        let mappedDepedency = "42"

        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.init { dependency in
            XCTAssertEqual(mappedDepedency, dependency)
            return originalMiddleware
        }
        let mappedReader = reader
            .dimap(
                transformMiddleware: { middleware -> MonoidMiddleware<String, String, String> in
                    XCTAssert(middleware === originalMiddleware)
                    return mappedMiddlware
                },
                extractOnlyDependenciesNeededForThisMiddleware: { (int: Int) -> String in
                    XCTAssertEqual(originalDependency, int)
                    return String(int)
                }
            )

        let resultingMiddleware = mappedReader.inject(originalDependency)
        XCTAssertEqual(resultingMiddleware.string, "a")
    }

    func testMiddlewareReaderFlatmap() {
        let originalMiddleware = MiddlewareMock<String, String, String>()
        let mappedMiddleware = MonoidMiddleware<String, String, String>(string: "a")
        let readerOfMappedMiddleware = MiddlewareReader<String, MonoidMiddleware<String, String, String>> { (string: String) in
            XCTAssertEqual("some dependency", string)
            return mappedMiddleware
        }

        let reader = MiddlewareReader<String, MiddlewareMock<String, String, String>>.init { dependency in
            XCTAssertEqual("some dependency", dependency)
            return originalMiddleware
        }
        let mappedReader = reader.flatMap { middleware -> MiddlewareReader<String, MonoidMiddleware<String, String, String>> in
            XCTAssert(middleware === originalMiddleware)
            return readerOfMappedMiddleware
        }

        let resultingMiddleware = mappedReader.inject("some dependency")
        XCTAssertEqual(resultingMiddleware.string, "a")
    }

}
