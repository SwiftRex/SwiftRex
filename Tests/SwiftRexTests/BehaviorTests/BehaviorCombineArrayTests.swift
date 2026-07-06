// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

@Suite("Behavior.combine(array)")
@MainActor
struct BehaviorCombineArrayTests {
    private struct S: Sendable, Equatable { var a = 0; var b = 0; var log = "" }
    private enum A: Sendable { case go }

    @Test func foldsAllInOrder() {
        let r1 = Behavior<A, S, Void>.reduce { _, s in s.a += 1; s.log += "1" }
        let r2 = Behavior<A, S, Void>.reduce { _, s in s.b += 1; s.log += "2" }
        let store = Store(initial: S(), behavior: .combine([r1, r2]), environment: ())
        store.dispatch(.go)
        #expect(store.state.a == 1)
        #expect(store.state.b == 1)
        #expect(store.state.log == "12") // left-to-right order preserved
    }

    @Test func emptyIsIdentity() {
        let store = Store(initial: S(), behavior: Behavior<A, S, Void>.combine([]), environment: ())
        store.dispatch(.go)
        #expect(store.state == S()) // no-op
    }
}
