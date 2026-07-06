// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SwiftRex
import Testing

@Suite
struct ElementActionTests {
    @Test func storesIdAndAction() {
        let ea = ElementAction("key", action: 42)
        #expect(ea.id == "key")
        #expect(ea.action == 42)
    }

    @Test func equatableEqual() {
        let lhs = ElementAction(1, action: "a")
        let rhs = ElementAction(1, action: "a")
        #expect(lhs == rhs)
    }

    @Test func equatableUnequalId() {
        #expect(ElementAction(1, action: "a") != ElementAction(2, action: "a"))
    }

    @Test func equatableUnequalAction() {
        #expect(ElementAction(1, action: "a") != ElementAction(1, action: "b"))
    }

    @Test func uUIDId() {
        let id = UUID()
        let ea = ElementAction(id, action: true)
        #expect(ea.id == id)
        #expect(ea.action)
    }
}
