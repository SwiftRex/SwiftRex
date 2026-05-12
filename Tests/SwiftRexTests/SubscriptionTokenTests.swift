import XCTest
import Foundation
@testable import SwiftRex

final class SubscriptionTokenTests: XCTestCase {
    func testCancelCallsClosure() {
        let called = LockProtected(false)
        let sut = SubscriptionToken { called.set(true) }
        sut.cancel()
        XCTAssertTrue(called.value)
    }

    func testEmptyDoesNotCrashOnCancel() {
        SubscriptionToken.empty.cancel()
    }

    func testCancelIsCalledEachTime() {
        let count = LockProtected(0)
        let sut = SubscriptionToken { count.mutate { $0 += 1 } }
        sut.cancel()
        sut.cancel()
        XCTAssertEqual(count.value, 2)
    }

    func testClosureReceivesNoArguments() {
        let received = LockProtected(false)
        let sut = SubscriptionToken { received.set(true) }
        XCTAssertFalse(received.value)
        sut.cancel()
        XCTAssertTrue(received.value)
    }
}
