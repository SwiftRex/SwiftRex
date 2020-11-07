import Foundation
@testable import SwiftRex
import XCTest

class DispatchedActionTests: XCTestCase {
    func testInitWithDispatcher() {
        let sut = DispatchedAction<Int>(42, dispatcher: ActionSource(file: "some-file", function: "some-function", line: 789, info: "some-info"))
        XCTAssertEqual(sut.action, 42)
        XCTAssertEqual(sut.dispatcher.file, "some-file")
        XCTAssertEqual(sut.dispatcher.function, "some-function")
        XCTAssertEqual(sut.dispatcher.line, 789)
        XCTAssertEqual(sut.dispatcher.info, "some-info")
    }

    func testInitWithFileFunctionLineInfo() {
        let sut = DispatchedAction<Int>(42, file: "some-file", function: "some-function", line: 789, info: "some-info")
        XCTAssertEqual(sut.action, 42)
        XCTAssertEqual(sut.dispatcher.file, "some-file")
        XCTAssertEqual(sut.dispatcher.function, "some-function")
        XCTAssertEqual(sut.dispatcher.line, 789)
        XCTAssertEqual(sut.dispatcher.info, "some-info")
    }

    func testInitWithActionOnly() {
        let file = #file
        let function = #function
        let line = UInt(#line + 1)
        let sut = DispatchedAction<Int>(42)
        XCTAssertEqual(sut.action, 42)
        XCTAssertEqual(sut.dispatcher.file, file)
        XCTAssertEqual(sut.dispatcher.function, function)
        XCTAssertEqual(sut.dispatcher.line, line)
        XCTAssertNil(sut.dispatcher.info)
    }

    func testMap() {
        let original = DispatchedAction<Int>(42, file: "some-file", function: "some-function", line: 789, info: "some-info")
        let sut = original.map(String.init)
        XCTAssertEqual(sut.action, "42")
        XCTAssertEqual(sut.dispatcher.file, "some-file")
        XCTAssertEqual(sut.dispatcher.function, "some-function")
        XCTAssertEqual(sut.dispatcher.line, 789)
        XCTAssertEqual(sut.dispatcher.info, "some-info")
    }
}
