import XCTest
@testable import SwiftRex

final class ShouldEmitValueTests: XCTestCase {
    // MARK: - .always

    func testAlwaysEmitsWhenStateUnchanged() {
        let sut = ShouldEmitValue<Int>.always
        XCTAssertTrue(sut.shouldEmit(old: 1, new: 1))
    }

    func testAlwaysEmitsWhenStateChanges() {
        let sut = ShouldEmitValue<Int>.always
        XCTAssertTrue(sut.shouldEmit(old: 1, new: 2))
    }

    // MARK: - .never

    func testNeverEmitsWhenStateChanges() {
        let sut = ShouldEmitValue<Int>.never
        XCTAssertFalse(sut.shouldEmit(old: 1, new: 2))
    }

    func testNeverEmitsWhenStateUnchanged() {
        let sut = ShouldEmitValue<Int>.never
        XCTAssertFalse(sut.shouldEmit(old: 1, new: 1))
    }

    // MARK: - .when

    func testWhenPredicateTrueEmits() {
        let sut = ShouldEmitValue<Int>.when { old, new in new > old }
        XCTAssertTrue(sut.shouldEmit(old: 1, new: 2))
    }

    func testWhenPredicateFalseDoesNotEmit() {
        let sut = ShouldEmitValue<Int>.when { old, new in new > old }
        XCTAssertFalse(sut.shouldEmit(old: 2, new: 1))
    }

    func testWhenPredicateReceivesCorrectOldAndNew() {
        var receivedOld: Int?
        var receivedNew: Int?
        let sut = ShouldEmitValue<Int>.when { old, new in
            receivedOld = old
            receivedNew = new
            return true
        }
        _ = sut.shouldEmit(old: 10, new: 20)
        XCTAssertEqual(receivedOld, 10)
        XCTAssertEqual(receivedNew, 20)
    }

    // MARK: - .whenDifferent (Equatable)

    func testWhenDifferentEmitsWhenDifferent() {
        let sut = ShouldEmitValue<Int>.whenDifferent()
        XCTAssertTrue(sut.shouldEmit(old: 1, new: 2))
    }

    func testWhenDifferentDoesNotEmitWhenEqual() {
        let sut = ShouldEmitValue<Int>.whenDifferent()
        XCTAssertFalse(sut.shouldEmit(old: 42, new: 42))
    }

    // MARK: - .whenDifferent(path:)

    func testWhenDifferentPathEmitsWhenPathChanges() {
        struct State { var x: Int; var y: Int }
        let sut = ShouldEmitValue<State>.whenDifferent(\.x)
        XCTAssertTrue(sut.shouldEmit(old: State(x: 1, y: 0), new: State(x: 2, y: 0)))
    }

    func testWhenDifferentPathDoesNotEmitWhenPathUnchanged() {
        struct State { var x: Int; var y: Int }
        let sut = ShouldEmitValue<State>.whenDifferent(\.x)
        XCTAssertFalse(sut.shouldEmit(old: State(x: 1, y: 0), new: State(x: 1, y: 99)))
    }

    func testWhenDifferentPathDoesNotEmitWhenEntireStateUnchanged() {
        struct State { var x: Int; var y: Int }
        let sut = ShouldEmitValue<State>.whenDifferent(\.x)
        XCTAssertFalse(sut.shouldEmit(old: State(x: 1, y: 1), new: State(x: 1, y: 1)))
    }
}
