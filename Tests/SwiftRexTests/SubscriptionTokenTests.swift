import XCTest
@testable import SwiftRex

final class SubscriptionTokenTests: XCTestCase {
    func testCancelCallsClosure() {
        var called = false
        let sut = SubscriptionToken { called = true }
        sut.cancel()
        XCTAssertTrue(called)
    }

    func testEmptyDoesNotCrashOnCancel() {
        SubscriptionToken.empty.cancel()
    }

    func testCancelIsCalledEachTime() {
        var count = 0
        let sut = SubscriptionToken { count += 1 }
        sut.cancel()
        sut.cancel()
        XCTAssertEqual(count, 2)
    }

    func testClosureReceivesNoArguments() {
        var received = false
        let sut = SubscriptionToken { received = true }
        XCTAssertFalse(received)
        sut.cancel()
        XCTAssertTrue(received)
    }
}
