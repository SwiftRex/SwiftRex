@testable import SwiftRex
import Testing

@Suite
struct ActionSourceTests {
    @Test func initStoresAllValues() {
        let sut = ActionSource(file: "File.swift", function: "myFunc()", line: 42)
        #expect(sut.file == "File.swift")
        #expect(sut.function == "myFunc()")
        #expect(sut.line == 42)
    }

    @Test func defaultParametersCaptureCallSite() {
        let line: UInt = #line; let sut = ActionSource()
        #expect(!(sut.file.isEmpty))
        #expect(!(sut.function.isEmpty))
        #expect(sut.line == line)
    }

    @Test func equatableEqualWhenSameValues() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 1)
        #expect(a == b)
    }

    @Test func equatableNotEqualWhenDifferentLine() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 2)
        #expect(a != b)
    }

    @Test func hashableConsistentWithEquatable() {
        let a = ActionSource(file: "f", function: "fn", line: 1)
        let b = ActionSource(file: "f", function: "fn", line: 1)
        #expect(a.hashValue == b.hashValue)
    }
}
