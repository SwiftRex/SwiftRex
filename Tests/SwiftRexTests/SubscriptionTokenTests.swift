// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SwiftRex
import Testing

@Suite
struct SubscriptionTokenTests {
    @Test func cancelCallsClosure() {
        let called = LockProtected(false)
        let sut = SubscriptionToken { called.set(true) }
        sut.cancel()
        #expect(called.value)
    }

    @Test func emptyDoesNotCrashOnCancel() {
        SubscriptionToken.empty.cancel()
    }

    @Test func cancelIsCalledEachTime() {
        let count = LockProtected(0)
        let sut = SubscriptionToken { count.mutate { $0 += 1 } }
        sut.cancel()
        sut.cancel()
        #expect(count.value == 2)
    }

    @Test func closureReceivesNoArguments() {
        let received = LockProtected(false)
        let sut = SubscriptionToken { received.set(true) }
        #expect(!(received.value))
        sut.cancel()
        #expect(received.value)
    }
}
