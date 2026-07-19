// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure
@testable import SwiftRex
import Testing

private let anySource = ActionSource(file: #file, function: #function, line: #line)

private enum AppAction: Equatable, Sendable {
    case counter(Int)
    case bumped(Int)
    case other(String)
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let counter = Prism<AppAction, Int>(
            preview: { if case let .counter(v) = $0 { v } else { nil } }, review: AppAction.counter)
        let bumped = Prism<AppAction, Int>(
            preview: { if case let .bumped(v) = $0 { v } else { nil } }, review: AppAction.bumped)
        let other = Prism<AppAction, String>(
            preview: { if case let .other(v) = $0 { v } else { nil } }, review: AppAction.other)
    }
    static let prism = Prisms()
}

private struct AppState: Equatable, Sendable { var count = 0 }

@Suite("Behavior — axis-separated on()")
@MainActor
struct BehaviorAxisBridgeTests {
    private var base: Behavior<AppAction, AppState, Void> { .handle { _, _ in .doNothing } }

    @Test func reduceOnlyMutates() {
        let behavior = base.on(.action(\.counter), reduce: { value, state in state.count += value })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(5))
        #expect(store.state.count == 5)
        store.dispatch(.other("ignored"))   // unmatched trigger → no-op
        #expect(store.state.count == 5)
    }

    @Test func reduceGuardedByWhen() {
        let behavior = base.on(.action(\.counter), when: { $0.count < 10 }, reduce: { v, s in s.count += v })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(6))          // 0 < 10 → 6
        #expect(store.state.count == 6)
        store.dispatch(.counter(6))          // 6 < 10 → 12
        #expect(store.state.count == 12)
        store.dispatch(.counter(6))          // 12 < 10 false → skipped
        #expect(store.state.count == 12)
    }

    @Test func embedDispatchAppliesReduce() {
        // The dispatch (Embeds) routes counter(n) → bumped(n); the co-located reduce mutates.
        let behavior = base.on(.action(\.counter), dispatch: .action(\.bumped), reduce: { v, s in s.count += v })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(4))
        #expect(store.state.count == 4)      // reduce ran (the routed action is inert here)
    }

    @Test func closureDispatchExtractPreview() {
        // Extract via a raw preview closure; route by transform.
        let behavior = base.on(
            .action(preview: { if case let .counter(v) = $0, v > 0 { v } else { nil } }),
            dispatch: .action(review: { AppAction.bumped($0 * 10) }),
            reduce: { v, s in s.count += v })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(3))
        #expect(store.state.count == 3)
        store.dispatch(.counter(-1))         // preview nil (not > 0) → no-op
        #expect(store.state.count == 3)
    }

    @Test func routedActionReportsDeclarationSiteNotBridgeInternals() {
        // The `.on` routed action must carry the source of the *declaration* — this line — not the
        // internal `Effect.just` inside Behavior+AxisBridge. Guards the #fileID forwarding.
        let declLine = UInt(#line + 1)
        let behavior = base.on(.action(\.counter), dispatch: .action(\.bumped))
        let reaction = behavior.handle(.counter(7), PreReducerContext(source: anySource, getter: { AppState() }))
        let effect = reaction.produce(PostReducerContext(environment: (), getter: { AppState() }))
        let sources = LockProtected([ActionSource]())
        subscribeAll(effect) { d in sources.mutate { $0.append(d.dispatcher) } }
        #expect(sources.value.map(\.line) == [declLine])
        #expect(sources.value.first?.file.hasSuffix("BehaviorAxisBridgeTests.swift") == true)
    }

    @Test func faithfulToPrismForm() {
        // The axis form and the prism form produce identical observable state.
        func run(_ behavior: Behavior<AppAction, AppState, Void>) -> Int {
            let store = Store(initial: AppState(), behavior: behavior, environment: ())
            store.dispatch(.counter(5)); store.dispatch(.counter(2))
            return store.state.count
        }
        let axis = base.on(.action(\.counter), when: { $0.count < 6 }, reduce: { v, s in s.count += v })
        let prism = base.on(.action(AppAction.prism.counter), when: { $0.count < 6 }, reduce: { v, s in s.count += v })
        #expect(run(axis) == run(prism))
    }
}
