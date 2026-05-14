@testable import SwiftRex
import XCTest

final class ElementActionTests: XCTestCase {
    func testStoresIdAndAction() {
        let ea = ElementAction("key", action: 42)
        XCTAssertEqual(ea.id, "key")
        XCTAssertEqual(ea.action, 42)
    }

    func testEquatableEqual() {
        XCTAssertEqual(ElementAction(1, action: "a"), ElementAction(1, action: "a"))
    }

    func testEquatableUnequalId() {
        XCTAssertNotEqual(ElementAction(1, action: "a"), ElementAction(2, action: "a"))
    }

    func testEquatableUnequalAction() {
        XCTAssertNotEqual(ElementAction(1, action: "a"), ElementAction(1, action: "b"))
    }

    func testUUIDId() {
        let id = UUID()
        let ea = ElementAction(id, action: true)
        XCTAssertEqual(ea.id, id)
        XCTAssertTrue(ea.action)
    }
}
