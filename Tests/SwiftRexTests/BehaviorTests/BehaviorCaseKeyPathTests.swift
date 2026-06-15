import CoreFP
@testable import SwiftRex
import Testing

// Hand-rolled `Prismatic` action (the shape `@Prisms` generates) so the test exercises `\.case`
// lifting without depending on the macro module.
private enum AppAction: Equatable, Sendable {
    case counter(Int)
    case other(String)
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let counter = Prism<AppAction, Int>(
            preview: { if case .counter(let value) = $0 { value } else { nil } },
            review: AppAction.counter
        )
        let other = Prism<AppAction, String>(
            preview: { if case .other(let value) = $0 { value } else { nil } },
            review: AppAction.other
        )
    }
    static let prism = Prisms()
}

@Suite("Behavior — \\.case action lifting")
@MainActor
struct BehaviorCaseKeyPathLiftTests {
    private func counterBehavior() -> Behavior<Int, Int, Void> {
        .handle { action, _ in .reduce { $0 += action } }
    }

    @Test func liftActionViaCaseKeyPath() {
        let lifted: Behavior<AppAction, Int, Void> = counterBehavior().liftAction(\.counter)
        let store = Store(initial: 0, behavior: lifted, environment: ())

        store.dispatch(.counter(5))
        #expect(store.state == 5)

        store.dispatch(.other("ignored")) // not matched by \.counter → no-op
        #expect(store.state == 5)
    }

    @Test func liftActionViaCaseKeyPathRewrapsProducedActions() async {
        // A behavior whose effect produces a local action; lifting must re-embed it via review.
        let producing = Behavior<Int, Int, Void>.handle { action, _ in
            action == 0
                ? .produce { _ in .just(7) }   // produce local action 7
                : .reduce { $0 += action }
        }
        let lifted: Behavior<AppAction, Int, Void> = producing.liftAction(\.counter)
        let store = Store(initial: 0, behavior: lifted, environment: ())

        store.dispatch(.counter(0)) // → effect produces .counter(7) (re-embedded), loops back, adds 7
        await Task.yield()
        await Task.yield()
        #expect(store.state == 7) // proves review re-embedded the produced action as .counter(7)
    }

    @Test func combinedLiftViaCaseKeyPath() {
        let lifted: Behavior<AppAction, Int, Void> = counterBehavior()
            .lift(action: \.counter, state: \.self, environment: { (_: Void) in () })
        let store = Store(initial: 0, behavior: lifted, environment: ())

        store.dispatch(.counter(3))
        #expect(store.state == 3)
    }
}
