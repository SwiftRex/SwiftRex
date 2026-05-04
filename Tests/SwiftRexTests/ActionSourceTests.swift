import XCTest
@testable import SwiftRex

final class ActionSourceTests: XCTestCase {
    func testInitStoresAllValues() {
        let sut = ActionSource(file: "File.swift", function: "myFunc()", line: 42, info: "extra")
        XCTAssertEqual(sut.file, "File.swift")
        XCTAssertEqual(sut.function, "myFunc()")
        XCTAssertEqual(sut.line, 42)
        XCTAssertEqual(sut.info, "extra")
    }

    func testInfoDefaultsToNil() {
        let sut = ActionSource(file: "f", function: "fn", line: 1)
        XCTAssertNil(sut.info)
    }

    func testDefaultParametersCaptureCallSite() {
        let line: UInt = #line; let sut = ActionSource()
        XCTAssertFalse(sut.file.isEmpty)
        XCTAssertFalse(sut.function.isEmpty)
        XCTAssertEqual(sut.line, line)
        XCTAssertNil(sut.info)
    }

    func testEquatableEqualWhenSameValues() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 1)
        XCTAssertEqual(a, b)
    }

    func testEquatableNotEqualWhenDifferentLine() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 2)
        XCTAssertNotEqual(a, b)
    }

    func testHashableConsistentWithEquatable() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 1)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
