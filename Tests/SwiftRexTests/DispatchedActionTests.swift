@testable import SwiftRex
import XCTest

final class DispatchedActionTests: XCTestCase {
    private let source = ActionSource(file: "f", function: "fn", line: 1)

    func testInitStoresActionAndDispatcher() {
        let sut = DispatchedAction(42, dispatcher: source)
        XCTAssertEqual(sut.action, 42)
        XCTAssertEqual(sut.dispatcher, source)
    }

    func testMapTransformsActionPreservesDispatcher() {
        let sut = DispatchedAction(3, dispatcher: source).map { $0 * 2 }
        XCTAssertEqual(sut.action, 6)
        XCTAssertEqual(sut.dispatcher, source)
    }

    func testMapStringToInt() {
        let sut = DispatchedAction("hello", dispatcher: source).map(\.count)
        XCTAssertEqual(sut.action, 5)
        XCTAssertEqual(sut.dispatcher, source)
    }

    func testCompactMapReturnsSomeWhenTransformSucceeds() {
        let sut = DispatchedAction(1, dispatcher: source).compactMap { $0 + 10 }
        XCTAssertEqual(sut?.action, 11)
        XCTAssertEqual(sut?.dispatcher, source)
    }

    func testCompactMapReturnsNilWhenTransformReturnsNil() {
        let sut: DispatchedAction<Int>? = DispatchedAction(1, dispatcher: source).compactMap { _ in nil }
        XCTAssertNil(sut)
    }

    func testCompactMapStringToOptionalInt() {
        let valid = DispatchedAction("42", dispatcher: source).compactMap(Int.init)
        XCTAssertEqual(valid?.action, 42)

        let invalid = DispatchedAction("abc", dispatcher: source).compactMap(Int.init)
        XCTAssertNil(invalid)
    }
}
