// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum AppAction: Equatable, Sendable {
    case counter(Int)
    case other(String)
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let counter = Prism<AppAction, Int>(
            preview: { if case let .counter(value) = $0 { value } else { nil } },
            review: AppAction.counter
        )
        let other = Prism<AppAction, String>(
            preview: { if case let .other(value) = $0 { value } else { nil } },
            review: AppAction.other
        )
    }

    static let prism = Prisms()
}

// Optional case properties (the `@Prisms` `.properties` shape) so `\.counter` resolves as
// `KeyPath<AppAction, Int?>` — the key-path spelling the `on` family uses.
extension AppAction {
    var counter: Int? { if case let .counter(value) = self { value } else { nil } }
    var other: String? { if case let .other(value) = self { value } else { nil } }
}

private struct AppState: Equatable, Sendable {
    var count: Int = 0
}

@Suite("Behavior — on(…, reduce:) with no dispatch")
@MainActor
struct BehaviorOnReduceTests {
    private var base: Behavior<AppAction, AppState, Void> { .handle { _, _ in .doNothing } }

    @Test func prismReduceMutatesWithoutDispatch() {
        let behavior = base.on(.action(AppAction.prism.counter), reduce: { value, state in state.count += value })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(5))
        #expect(store.state.count == 5)
        store.dispatch(.other("ignored")) // unmatched → no-op
        #expect(store.state.count == 5)
    }

    @Test func prismKeyPathReduceMutatesWithoutDispatch() {
        let behavior = base.on(.action(AppAction.prism.counter), reduce: { value, state in state.count += value })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(3))
        #expect(store.state.count == 3)
    }

    @Test func reduceGuardedByPredicate() {
        let behavior = base.on(.action(AppAction.prism.counter), when: { $0.count < 10 }, reduce: { value, state in state.count += value })
        let store = Store(initial: AppState(), behavior: behavior, environment: ())
        store.dispatch(.counter(6))
        #expect(store.state.count == 6)
        store.dispatch(.counter(6)) // count == 6, predicate true → applies → 12
        #expect(store.state.count == 12)
        store.dispatch(.counter(6)) // count == 12, predicate false → skipped
        #expect(store.state.count == 12)
    }
}
