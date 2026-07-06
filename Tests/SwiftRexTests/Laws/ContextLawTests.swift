// SPDX-License-Identifier: Apache-2.0

@testable import SwiftRex
import Testing

// Functor laws for the dispatch contexts. Both are observed through their state reads
// (`stateBefore` / `liveState`), comparing the resulting optional state. `PreReducerContext` is
// `@MainActor` (even construction), and `liveState` is `@MainActor`, so those reads run under
// `MainActor.assumeIsolated` inside `@MainActor` suites (where the assumption holds). Environment
// is non-isolated, so the `mapEnvironment` laws need no isolation.

private let ctxSource = ActionSource(file: "law.swift", function: "law()", line: 0)
private let identityInt: @Sendable (Int) -> Int = { $0 }

@Suite("PreReducerContext — Functor laws")
@MainActor
struct PreReducerContextLawTests {
    @Test func mapIdentity() {
        forAll(smallInt.optional()) { state in
            MainActor.assumeIsolated {
                let ctx = PreReducerContext<Int>(source: ctxSource, getter: { state })
                return ctx.map(identityInt).stateBefore == ctx.stateBefore
            }
        }
    }

    @Test func mapComposition() {
        forAll(smallInt.optional(), intFuncGen, intFuncGen) { state, f, g in
            MainActor.assumeIsolated {
                let ctx = PreReducerContext<Int>(source: ctxSource, getter: { state })
                return ctx.map(f).map(g).stateBefore == ctx.map { g(f($0)) }.stateBefore
            }
        }
    }

    @Test func compactMapComposition() {
        forAll(smallInt.optional(), intKleisliGen, intKleisliGen) { state, f, g in
            MainActor.assumeIsolated {
                let ctx = PreReducerContext<Int>(source: ctxSource, getter: { state })
                return ctx.compactMap(f).compactMap(g).stateBefore == ctx.compactMap { f($0).flatMap(g) }.stateBefore
            }
        }
    }
}

@Suite("PostReducerContext — Functor laws")
@MainActor
struct PostReducerContextLawTests {
    // MARK: State axis (observed via liveState)

    @Test func mapIdentity() {
        forAll(smallInt.optional()) { state in
            MainActor.assumeIsolated {
                let ctx = PostReducerContext<Int, Void>(environment: (), getter: { state })
                return ctx.map(identityInt).liveState == ctx.liveState
            }
        }
    }

    @Test func mapComposition() {
        forAll(smallInt.optional(), intFuncGen, intFuncGen) { state, f, g in
            MainActor.assumeIsolated {
                let ctx = PostReducerContext<Int, Void>(environment: (), getter: { state })
                return ctx.map(f).map(g).liveState == ctx.map { g(f($0)) }.liveState
            }
        }
    }

    @Test func compactMapComposition() {
        forAll(smallInt.optional(), intKleisliGen, intKleisliGen) { state, f, g in
            MainActor.assumeIsolated {
                let ctx = PostReducerContext<Int, Void>(environment: (), getter: { state })
                return ctx.compactMap(f).compactMap(g).liveState == ctx.compactMap { f($0).flatMap(g) }.liveState
            }
        }
    }

    // MARK: Environment axis (observed via environment — non-isolated)

    @Test func mapEnvironmentIdentity() {
        forAll(smallInt) { env in
            let ctx = PostReducerContext<Int, Int>(environment: env, getter: { nil })
            return ctx.mapEnvironment(identityInt).environment == ctx.environment
        }
    }

    @Test func mapEnvironmentComposition() {
        forAll(smallInt, intFuncGen, intFuncGen) { env, f, g in
            let ctx = PostReducerContext<Int, Int>(environment: env, getter: { nil })
            return ctx.mapEnvironment(f).mapEnvironment(g).environment == ctx.mapEnvironment { g(f($0)) }.environment
        }
    }
}
