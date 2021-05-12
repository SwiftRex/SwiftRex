import Foundation
@testable import SwiftRex
import XCTest

class ShouldEmitValuesTests: XCTestCase {
    func testAlwaysShouldEmit() {
        let sut = ShouldEmitValue<String>.always
        let responses = [
            sut.shouldEmit(previous: "a", new: "b"),
            sut.shouldEmit(previous: "b", new: "c"),
            sut.shouldEmit(previous: "c", new: "c"),
            sut.shouldEmit(previous: "c", new: "a")
        ]
        XCTAssertEqual([true, true, true, true], responses)
    }

    func testAlwaysShouldRemove() {
        let sut = ShouldEmitValue<String>.always
        let responses = [
            sut.shouldRemove(previous: "a", new: "b"),
            sut.shouldRemove(previous: "b", new: "c"),
            sut.shouldRemove(previous: "c", new: "c"),
            sut.shouldRemove(previous: "c", new: "a")
        ]
        XCTAssertEqual([false, false, false, false], responses)
    }

    func testNeverShouldEmit() {
        let sut = ShouldEmitValue<String>.never
        let responses = [
            sut.shouldEmit(previous: "a", new: "b"),
            sut.shouldEmit(previous: "b", new: "c"),
            sut.shouldEmit(previous: "c", new: "c"),
            sut.shouldEmit(previous: "c", new: "a")
        ]
        XCTAssertEqual([false, false, false, false], responses)
    }

    func testNeverShouldRemove() {
        let sut = ShouldEmitValue<String>.never
        let responses = [
            sut.shouldRemove(previous: "a", new: "b"),
            sut.shouldRemove(previous: "b", new: "c"),
            sut.shouldRemove(previous: "c", new: "c"),
            sut.shouldRemove(previous: "c", new: "a")
        ]
        XCTAssertEqual([true, true, true, true], responses)
    }

    func testWhenShouldEmit() {
        var seen: Set<String> = []
        let neverSeen: (String, String) -> Bool = { previous, new in
            let neverSeen = !seen.contains(new)
            seen.insert(previous)
            seen.insert(new)
            return neverSeen
        }
        let sut = ShouldEmitValue<String>.when(neverSeen)
        let responses = [
            sut.shouldEmit(previous: "a", new: "b"),
            sut.shouldEmit(previous: "b", new: "c"),
            sut.shouldEmit(previous: "c", new: "c"),
            sut.shouldEmit(previous: "c", new: "a")
        ]
        XCTAssertEqual([true, true, false, false], responses)
    }

    func testWhenShouldRemove() {
        var seen: Set<String> = []
        let neverSeen: (String, String) -> Bool = { previous, new in
            let neverSeen = !seen.contains(new)
            seen.insert(previous)
            seen.insert(new)
            return neverSeen
        }
        let sut = ShouldEmitValue<String>.when(neverSeen)
        let responses = [
            sut.shouldRemove(previous: "a", new: "b"),
            sut.shouldRemove(previous: "b", new: "c"),
            sut.shouldRemove(previous: "c", new: "c"),
            sut.shouldRemove(previous: "c", new: "a")
        ]
        XCTAssertEqual([false, false, true, true], responses)
    }

    func testWhenDifferentShouldEmit() {
        let sut = ShouldEmitValue<String>.whenDifferent
        let responses = [
            sut.shouldEmit(previous: "a", new: "b"),
            sut.shouldEmit(previous: "b", new: "c"),
            sut.shouldEmit(previous: "c", new: "c"),
            sut.shouldEmit(previous: "c", new: "a")
        ]
        XCTAssertEqual([true, true, false, true], responses)
    }

    func testWhenDifferentShouldRemove() {
        let sut = ShouldEmitValue<String>.whenDifferent
        let responses = [
            sut.shouldRemove(previous: "a", new: "b"),
            sut.shouldRemove(previous: "b", new: "c"),
            sut.shouldRemove(previous: "c", new: "c"),
            sut.shouldRemove(previous: "c", new: "a")
        ]
        XCTAssertEqual([false, false, true, false], responses)
    }
}
