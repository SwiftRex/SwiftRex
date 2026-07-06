// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

@Suite
struct DispatchedActionTests {
    private let source = ActionSource(file: "f", function: "fn", line: 1)

    @Test func initStoresActionAndDispatcher() {
        let sut = DispatchedAction(42, dispatcher: source)
        #expect(sut.action == 42)
        #expect(sut.dispatcher == source)
    }

    @Test func mapTransformsActionPreservesDispatcher() {
        let sut = DispatchedAction(3, dispatcher: source).map { $0 * 2 }
        #expect(sut.action == 6)
        #expect(sut.dispatcher == source)
    }

    @Test func mapStringToInt() {
        let sut = DispatchedAction("hello", dispatcher: source).map(\.count)
        #expect(sut.action == 5)
        #expect(sut.dispatcher == source)
    }

    @Test func compactMapReturnsSomeWhenTransformSucceeds() {
        let sut = DispatchedAction(1, dispatcher: source).compactMap { $0 + 10 }
        #expect(sut?.action == 11)
        #expect(sut?.dispatcher == source)
    }

    @Test func compactMapReturnsNilWhenTransformReturnsNil() {
        let sut: DispatchedAction<Int>? = DispatchedAction(1, dispatcher: source).compactMap { _ in nil }
        #expect(sut == nil)
    }

    @Test func compactMapStringToOptionalInt() {
        let valid = DispatchedAction("42", dispatcher: source).compactMap(Int.init)
        #expect(valid?.action == 42)

        let invalid = DispatchedAction("abc", dispatcher: source).compactMap(Int.init)
        #expect(invalid == nil)
    }
}
