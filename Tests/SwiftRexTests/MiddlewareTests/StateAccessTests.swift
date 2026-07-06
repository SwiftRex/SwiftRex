// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

// MARK: - PreReducerContext tests

@Suite("PreReducerContext")
@MainActor
struct PreReducerContextTests {
    @Test func stateBeforeReturnsCurrentValue() {
        var state = 42
        let src = ActionSource(file: #file, function: #function, line: #line)
        let ctx = PreReducerContext<Int>(source: src, getter: { state })
        #expect(ctx.stateBefore == 42)
        state = 99
        #expect(ctx.stateBefore == 99)
    }

    @Test func stateBeforeReturnsNilWhenGetterReturnsNil() {
        let src = ActionSource(file: #file, function: #function, line: #line)
        let ctx = PreReducerContext<Int>(source: src, getter: { nil })
        #expect(ctx.stateBefore == nil)
    }

    @Test func sourceIsPreserved() {
        let src = ActionSource(file: "foo.swift", function: "bar()", line: 7)
        let ctx = PreReducerContext<Int>(source: src, getter: { 0 })
        #expect(ctx.source.file == "foo.swift")
        #expect(ctx.source.function == "bar()")
        #expect(ctx.source.line == 7)
    }

    @Test func mapProjectsToSubState() {
        let ctx = PreReducerContext<(Int, String)>(
            source: ActionSource(file: #file, function: #function, line: #line),
            getter: { (10, "hello") }
        )
        #expect(ctx.map { $0.0 }.stateBefore == 10)
    }

    @Test func mapReturnsNilWhenParentIsNil() {
        let ctx = PreReducerContext<Int>(
            source: ActionSource(file: #file, function: #function, line: #line),
            getter: { nil }
        )
        #expect(ctx.map { $0 * 2 }.stateBefore == nil)
    }

    @Test func compactMapProjectsToOptionalSubState() {
        let ctx = PreReducerContext<Int?>(
            source: ActionSource(file: #file, function: #function, line: #line),
            getter: { .some(5) }
        )
        #expect(ctx.compactMap { $0 }.stateBefore == 5)
    }

    @Test func compactMapReturnsNilWhenFReturnsNil() {
        let ctx = PreReducerContext<Int>(
            source: ActionSource(file: #file, function: #function, line: #line),
            getter: { 42 }
        )
        #expect(ctx.compactMap { _ in nil as Int? }.stateBefore == nil)
    }

    @Test func compactMapReturnsNilWhenParentIsNil() {
        let ctx = PreReducerContext<Int>(
            source: ActionSource(file: #file, function: #function, line: #line),
            getter: { nil }
        )
        #expect(ctx.compactMap { Optional($0) }.stateBefore == nil)
    }

    @Test func mapPreservesSource() {
        let src = ActionSource(file: "x.swift", function: "f()", line: 1)
        let ctx = PreReducerContext<Int>(source: src, getter: { 0 })
        let mapped: PreReducerContext<String> = ctx.map(String.init)
        #expect(mapped.source.file == "x.swift")
    }
}

// MARK: - PostReducerContext tests

@Suite("PostReducerContext")
@MainActor
struct PostReducerContextTests {
    @Test func liveStateReflectsCurrentStoreState() {
        // liveState is a live read: it tracks the backing state, it is not a frozen snapshot.
        var state = 42
        let ctx = PostReducerContext<Int, Void>(environment: (), getter: { state })
        #expect(ctx.liveState == 42)
        state = 99
        #expect(ctx.liveState == 99)
    }

    @Test func liveStateReturnsNilWhenGetterReturnsNil() {
        let ctx = PostReducerContext<Int, Void>(environment: (), getter: { nil })
        #expect(ctx.liveState == nil)
    }

    @Test func environmentIsPreserved() {
        struct Deps: Sendable { let x: Int }
        let ctx = PostReducerContext<Int, Deps>(environment: Deps(x: 7), getter: { nil })
        #expect(ctx.environment.x == 7)
    }

    @Test func mapProjectsStateToSubState() {
        let ctx = PostReducerContext<(Int, String), Void>(environment: (), getter: { (10, "hello") })
        #expect(ctx.map { $0.0 }.liveState == 10)
    }

    @Test func mapReturnsNilWhenParentIsNil() {
        let ctx = PostReducerContext<Int, Void>(environment: (), getter: { nil })
        #expect(ctx.map { $0 * 2 }.liveState == nil)
    }

    @Test func mapPreservesEnvironment() {
        struct E: Sendable { let v: Int }
        let ctx = PostReducerContext<Int, E>(environment: E(v: 99), getter: { 0 })
        #expect(ctx.map { $0 + 1 }.environment.v == 99)
    }

    @Test func compactMapProjectsToOptionalSubState() {
        let ctx = PostReducerContext<Int?, Void>(environment: (), getter: { .some(5) })
        #expect(ctx.compactMap { $0 }.liveState == 5)
    }

    @Test func compactMapReturnsNilWhenFReturnsNil() {
        let ctx = PostReducerContext<Int, Void>(environment: (), getter: { 42 })
        #expect(ctx.compactMap { _ in nil as Int? }.liveState == nil)
    }

    @Test func compactMapReturnsNilWhenParentIsNil() {
        let ctx = PostReducerContext<Int, Void>(environment: (), getter: { nil })
        #expect(ctx.compactMap { Optional($0) }.liveState == nil)
    }

    @Test func mapEnvironmentTransformsEnvironment() {
        struct Global: Sendable { let sub: Int }
        let ctx = PostReducerContext<Int, Global>(environment: Global(sub: 42), getter: { nil })
        let projected = ctx.mapEnvironment { $0.sub }
        #expect(projected.environment == 42)
    }

    @Test func mapEnvironmentPreservesGetter() {
        struct Global: Sendable { let sub: Int }
        let ctx = PostReducerContext<Int, Global>(environment: Global(sub: 0), getter: { 77 })
        let projected = ctx.mapEnvironment { $0.sub }
        #expect(projected.liveState == 77)
    }
}
