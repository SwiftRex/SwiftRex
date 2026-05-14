import CoreFP
@testable import SwiftRex
import Testing

@Suite("StateAccess")
@MainActor
struct StateAccessTests {
    @Test func snapshotStateReturnsCurrentValue() {
        var state = 42
        let access = StateAccess<Int> { state }
        #expect(access.snapshotState() == 42)
        state = 99
        #expect(access.snapshotState() == 99)
    }

    @Test func snapshotStateReturnsNilWhenGetReturnsNil() {
        let access = StateAccess<Int> { nil }
        #expect(access.snapshotState() == nil)
    }

    @Test func mapProjectsToSubState() {
        let access = StateAccess<(Int, String)> { (10, "hello") }
        #expect(access.map { $0.0 }.snapshotState() == 10)
    }

    @Test func mapReturnsNilWhenParentIsNil() {
        let access = StateAccess<Int> { nil }
        #expect(access.map { $0 * 2 }.snapshotState() == nil)
    }

    @Test func flatMapProjectsToOptionalSubState() {
        let access = StateAccess<Int?> { .some(5) }
        #expect(access.flatMap { $0 }.snapshotState() == 5)
    }

    @Test func flatMapReturnsNilWhenFReturnsNil() {
        let access = StateAccess<Int> { 42 }
        #expect(access.flatMap { _ in nil as Int? }.snapshotState() == nil)
    }

    @Test func flatMapReturnsNilWhenParentIsNil() {
        let access = StateAccess<Int> { nil }
        #expect(access.flatMap { Optional($0) }.snapshotState() == nil)
    }
}
